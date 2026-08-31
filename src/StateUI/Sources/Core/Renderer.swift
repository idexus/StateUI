// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The render loop.
//
// Holds the application, produces the message on demand, and tracks whether
// anything changed since the last render. The host on the C# side drives it:
// it asks for a message, applies it, reports events back, and asks again when
// told the tree is dirty.
//
// The author's closure runs in full every time - that is what makes state
// updates work without invalidating anything by hand. What is SENT is the
// difference against what C# is already showing; see Diff.swift.

// Dispatch and not Foundation, for the lock below: libdispatch exists on every
// platform this targets, and Foundation on Windows links ICU.
import Dispatch

/// `@unchecked Sendable` for the same reason as State: the safety guarantee is
/// external - the C# host calls in only from the thread MAUI draws on - and
/// cannot be expressed structurally.
public final class Renderer: @unchecked Sendable {
    // Legal as a plain static let because the class declares @unchecked
    // Sendable above.
    //
    // The type system DOES express that thread, as @MainThread - but for
    // handlers, which are the part that can suspend and therefore the part that
    // could land anywhere. The renderer itself is only ever entered from a
    // @_cdecl, synchronously, so isolating it would buy a promise the compiler
    // cannot check across the boundary anyway and would cost every entry point
    // an assumeIsolated. See Core/MainThread.swift.

    /// The one renderer. There is a single host per process, so a second would
    /// have nothing to render into.
    public static let shared = Renderer()

    private var application: Application?
    private var dirty = true

    /// The state that has changed since the last render, by storage identity -
    /// what `stateChanged` collects and the clean walk in Core/Diff.swift acts
    /// on. Behind `guarded`, because a write may come from any thread.
    private var changed: Set<ObjectIdentifier> = []

    /// What each of those is CALLED - the author's own property name, taken
    /// as the write lands and handed to the walk, which is what lets a view
    /// say why it is being described. See Core/Builds.swift.
    private var names: [ObjectIdentifier: String] = [:]

    /// Whether something asked for a render without naming what changed - a
    /// plain `setNeedsRender`, which is what registering the application is.
    /// The render then builds the whole tree: not knowing what moved must
    /// never mean guessing that nothing did.
    private var untracked = true

    /// What the last window build read OUTSIDE every composed view - the
    /// arrangement itself: which section is showing, the bound path, whether
    /// the flyout is presented. A change to any of it means the window must be
    /// built again, so there is no clean walk to take.
    private var rootReads: Set<ObjectIdentifier> = []

    private let differ = Differ()

    /// This session's numbering of every name the wire carries - see
    /// Core/Wire.swift. Touched only while a message is encoded, which
    /// happens on the host's one thread.
    private let wireDictionary = WireDictionary()

    /// The tree as C# is showing it, as far as this side knows.
    private var rendered: RenderedNode?

    /// Which render produced `rendered`.
    ///
    /// A patch only makes sense against the exact tree it was computed from, so
    /// the caller quotes back the generation it holds and gets a patch only if
    /// it still matches. Anything else - a host rendering for the first time, a
    /// host that failed halfway through applying the last message, a second host
    /// showing the same interface - gets the whole tree instead. Without this,
    /// the two sides would drift apart silently, which is the failure mode every
    /// incremental protocol has to answer for.
    private var generation: Int32 = 0

    /// How many renders in a row ended with the tree dirty again - see the
    /// end of `renderWire`, where a streak this long is reported as a view
    /// writing state from its own build.
    private var selfDirtied = 0

    /// The streak length that reads as a render loop rather than as a write
    /// that happened to cross mid-render. A legitimate crossing dirties one
    /// render; a ticker at its fastest dirties one in a dozen.
    static let selfDirtyLimit = 16

    /// Guards the command queue, the completion registry and the counters
    /// beside them - everything `send` and `call` touch.
    ///
    /// They need a lock where nothing else here does because they are the one
    /// part of the renderer a CHILD TASK reaches. `async let` runs its child on
    /// the cooperative pool - that is Swift's design, a child task does not
    /// inherit the parent's actor - so two animations started with `async let`
    /// call `send` from pool threads while the UI thread is taking commands and
    /// dispatching completions. Unguarded, that is a data race on this
    /// dictionary and array: a lost continuation on a good day, which reads as
    /// a handler frozen at its `await`, and corrupted memory on a bad one,
    /// which takes real devices down. Measured on Mac Catalyst, an iOS device
    /// and an Android device alike.
    ///
    /// A serial `DispatchQueue` as a mutex for the reason `MainThreadExecutor`
    /// uses one: libdispatch exists on every platform this targets, and
    /// Foundation's locks arrive with ICU on Windows. Closures taken OUT of the
    /// registry are always invoked outside the lock - `dispatch` resumes a
    /// continuation, and a resume that re-entered `send` would deadlock on a
    /// queue `sync` cannot re-enter.
    private let guarded = DispatchQueue(label: "StateUI.Renderer.commands")

    /// Acts waiting for the host to collect them - see Command.swift.
    private var commands: [Command] = []

    /// Continuations waiting for an act to finish.
    ///
    /// Kept apart from the element handlers because they belong to no element:
    /// they are one-shot, they outlive the render that created them, and they
    /// must not be swept away when the tree is rebuilt. Their ids count
    /// DOWNWARDS from -1, which is what keeps the two kinds apart on a boundary
    /// that carries nothing but a number.
    ///
    /// This is the token registry an `await` needs: a completion id is how the
    /// host says which act it has finished.
    private var completions: [Int: (Reply) -> Void] = [:]
    private var nextCompletionId = -1

    /// The completion ids of the last batch `takeCommandsWire` handed out -
    /// the take's RECEIPT, which is what lets a batch the host could not read
    /// be failed back by id. Behind `guarded`, like the registry it points
    /// into. See `failTakenCommands`.
    private var takenCompletions: [Int] = []

    /// How many resumes the host has reported that have not come back yet.
    /// Behind `guarded`, because the far side of a child task's `await` is a
    /// pool thread.
    private var resumes = 0

    /// How many handlers have been told their act is over and have not run a
    /// line since.
    ///
    /// Raised the moment a continuation is resumed and lowered by the handler
    /// itself, as the first thing it does on the other side of its `await`. So
    /// it is not an estimate: while it is above zero there is a handler that has
    /// been told its act is over and has not run a line since.
    ///
    /// It exists because the job a resume produces does not exist yet when the
    /// host reports the outcome - measured - so the host has to ask again, and
    /// this is what tells it whether asking again is still worth anything. See
    /// `StateUISession.DrainWhenTheResumeArrives`.
    var resumesPending: Int { guarded.sync { resumes } }

    private init() {}

    /// Registers the application. Called through `stateUIUseApp`.
    ///
    /// The application is asked for a window on every render rather than being
    /// asked once and remembered, which is what makes state changes show up
    /// without any explicit invalidation of individual controls.
    public func setApplication(_ application: Application) {
        self.application = application
        setNeedsRender()
    }

    /// Marks the tree as needing a re-render, without saying what changed -
    /// so the render that follows builds the whole tree. State that can name
    /// itself goes through `stateChanged` instead, and the render rebuilds
    /// only what read it.
    ///
    /// Behind `guarded`, and followed by a wake, because a write may come
    /// from any thread: a handler on `@MainThread` lands inside a drain, whose
    /// end renders it, while a `Task.detached` or an `async let` child that
    /// writes from the cooperative pool has nothing driving it - the flag is
    /// what the host's parked thread counts as work and the wake is what
    /// makes it look. The storage itself is locked in Core/State.swift; this
    /// is the other half of what makes a write from anywhere whole.
    public func setNeedsRender() {
        guarded.sync {
            dirty = true
            untracked = true
        }

        // Outside the lock, the shape `send` has: a wake only signals a
        // thread, and the executor's lock must never be taken inside this one.
        MainThreadExecutor.shared.poke()
    }

    /// Records that a piece of state was read - what `@State` and the
    /// accessors `@StateClass` writes call on every read.
    ///
    /// While a view is being built it records a dependency: the next render
    /// rebuilds that view when this state changes, and can leave it alone when
    /// it does not. Anywhere else - a handler, a task - it costs nearly
    /// nothing and records nothing. See Core/Invalidation.swift.
    public func stateRead(_ state: AnyObject) {
        ReadScope.note(ObjectIdentifier(state))
    }

    /// Records that a piece of state has changed, and asks for a render - the
    /// tracked half of `setNeedsRender`, called by every `@State` write and by
    /// the accessors `@StateClass` writes.
    ///
    /// Naming the state is what lets the render that follows rebuild only the
    /// views whose build read it. Marks and wakes exactly as `setNeedsRender`
    /// does - the wake is what makes a write with no job and no command
    /// behind it reach the screen before the next event, and `wakeArmed`
    /// folds a thousand of them inside one drain into one signal.
    public func stateChanged(_ state: AnyObject) {
        let id = ObjectIdentifier(state)

        // What it is CALLED, taken while the object is in hand: a `@State`
        // knows the property it was declared as, and anything else - a model,
        // a ticker - is called by its type, which is what an author calls it
        // too. See Core/Builds.swift.
        let name = (state as? NamedState)?.origin

        guarded.sync {
            dirty = true
            changed.insert(id)

            if let name = name {
                names[id] = name
            } else if names[id] == nil {
                names[id] = String(describing: type(of: state))
            }
        }

        MainThreadExecutor.shared.poke()
    }

    // MARK: - Continuous values

    /// Every channel anything has asked a number for, weakly - the storage
    /// belongs to the view that declared it, and a channel outlives nothing.
    /// See Core/Channel.swift.
    private var channels: [Int32: () -> ChannelStorage?] = [:]

    /// The next channel number to issue. Never zero, which is what a node with
    /// no continuous value writes.
    private var nextChannel: Int32 = 1

    /// The number the host quotes this value back by, issued once and then
    /// kept on the value itself.
    ///
    /// - Parameter storage: the value being followed.
    /// - Returns: its channel number.
    func channel(for storage: ChannelStorage) -> Int32 {
        if let issued = storage.channel { return issued }

        let issued = nextChannel
        nextChannel += 1
        storage.channel = issued

        guarded.sync {
            channels[issued] = { [weak storage] in storage }
        }

        return issued
    }

    /// Says where a channel's value now stands, WITHOUT asking for a render -
    /// which is the whole of the point. Called by the host as the platform
    /// reports.
    ///
    /// - Parameters:
    ///   - channel: the number the value was issued.
    ///   - value: where it stands now.
    func moved(_ channel: Int32, to value: Double) {
        let found = guarded.sync { channels[channel] }

        guard let storage = found?() else {
            guarded.sync { channels[channel] = nil }
            return
        }

        storage.crossing = value
    }

    /// Puts the channel numbering back to where a fresh process has it, and
    /// forgets the number every value was issued.
    ///
    /// For the TESTS, which share one renderer across a whole run: a fixture
    /// is a contract about BYTES, and a channel number that depended on which
    /// tests ran first would make one that cannot be compared. Nothing an
    /// application can reach, and nothing a running interface would survive -
    /// a value whose number is forgotten while the host still quotes it would
    /// be told about somebody else's movement.
    func clearChannels() {
        let issued = guarded.sync { () -> [() -> ChannelStorage?] in
            let held = Array(channels.values)
            channels.removeAll()
            return held
        }

        for storage in issued {
            storage()?.channel = nil
        }

        nextChannel = 1
    }

    /// The arithmetic a channel-followed layout is placed by.
    ///
    /// - Parameter rule: the id the differ issued and the message carried.
    /// - Returns: the rule, or nothing where the layout has gone.
    func placement(_ rule: Int) -> PlacementRule? { differ.placement(rule) }

    /// What the next render will act on - read by the tests, which drive a
    /// Differ of their own rather than going through `renderWire`.
    var pendingChanges: Set<ObjectIdentifier> { guarded.sync { changed } }

    /// What those changes are CALLED - the other half of what a test hands a
    /// differ of its own, so a build there is explained in the same names an
    /// application's is. See Core/Builds.swift.
    var pendingNames: [ObjectIdentifier: String] { guarded.sync { names } }

    /// Whether anything asked for a render without naming what changed - the
    /// other thing a test needs to see.
    var hasUntrackedCause: Bool { guarded.sync { untracked } }

    /// Puts the invalidation bookkeeping back to "nothing has changed", so a
    /// test starts from a known state whatever ran before it.
    func clearInvalidation() {
        guarded.sync {
            dirty = false
            changed.removeAll()
            names.removeAll()
            untracked = false
        }
    }

    /// Whether anything has changed since the last render. The host polls this
    /// rather than being called back, so nothing here has to reach into C#.
    public var needsRender: Bool { guarded.sync { dirty } }

    /// Builds the current tree and serializes what changed since `baseline`.
    ///
    /// `baseline` is the generation the caller is holding; pass 0 - or anything
    /// that is not the current generation - to be sent the complete tree.
    ///
    /// The complete tree is still reconciled AGAINST the one this side is
    /// showing, never against nothing: a resync changes what the message
    /// carries, not who anything is. Passing nil here instead - measured -
    /// resets every `@State` to its initial value and leaves the whole
    /// previous handler registry live for ever, with stale controls still able
    /// to reach the leaked closures.
    func renderWire(baseline: Int32) -> [UInt8] {
        // On the very first render the two agree at zero, and the tree is
        // complete all the same - there is nothing to have changed since.
        let describeAll = baseline != generation || rendered == nil

        // Taken AND cleared, in one locked step, before anything is built: a
        // write that lands while this render runs - a flight booked from a
        // child task, a write an author makes off-thread - then stays on the
        // books and asks for the NEXT render, instead of being wiped by this
        // one's clear without ever having been looked at. The cost is one
        // clean walk that diffs to nothing when this render had already seen
        // the value, which is the direction Core/Invalidation.swift allows
        // the bookkeeping to err in; the other direction is a control that
        // stays stale and a handler that stays suspended on a walk nobody
        // drew.
        let (changedNow, untrackedNow, namesNow):
            (Set<ObjectIdentifier>, Bool, [ObjectIdentifier: String]) = guarded.sync {
            let taken = (changed, untracked, names)
            changed.removeAll()
            names.removeAll()
            untracked = false
            dirty = false
            return taken
        }

        // Taken once, for the same reason: the walk asks about a flight for
        // every armed property it emits, and none of those asks may reach a
        // lock. What this render does not carry is answered below.
        let offered = offeredFlights()
        differ.flights = offered
        differ.named = namesNow
        differ.snapping = offeredSnaps()

        let result: (node: RenderedNode, patch: Patch)

        if let current = rendered, !describeAll, !untrackedNow,
            rootReads.isDisjoint(with: changedNow) {
            // Every cause of this render named the state it wrote, and none of
            // it was read by the window build itself - so the window is not
            // built at all. The differ walks the tree this side is already
            // showing and rebuilds exactly the views whose state changed; a
            // view whose parent was left alone still holds the inputs that
            // parent gave it, which is what makes the skip sound. See
            // Core/Invalidation.swift and `Differ.revisit`.
            result = differ.revisit(current, changed: changedNow)
        } else {
            let (built, reads) = ReadScope.collect { root }
            rootReads = reads
            differ.motion = built.motion

            result = differ.reconcile(
                rendered,
                with: built.tree,
                styles: built.styles,
                describeAll: describeAll,
                changed: changedNow)
        }

        rendered = result.node
        generation &+= 1

        // Zero is the caller's own "start over" and never a generation this
        // side issues, so a counter that wraps walks past it.
        if generation == 0 { generation = 1 }

        // A render that left the tree dirty is, once, a write that crossed
        // from a pool thread while it ran. A STREAK of them is a view whose
        // build writes the state it reads - the one thing the bookkeeping
        // above would turn into a render loop - and the streak is how that
        // author error is told apart from the legitimate crossing without
        // knowing which thread wrote: nothing that crosses legitimately
        // crosses on every consecutive render. Reported, and the tree wiped
        // clean once, so the loop ends and the log names it.
        if guarded.sync(execute: { dirty }) {
            selfDirtied += 1

            if selfDirtied >= Renderer.selfDirtyLimit {
                clearInvalidation()
                selfDirtied = 0
                report(StateUIError(message: """
                    A view writes state while it is being built - every one of \
                    \(Renderer.selfDirtyLimit) consecutive renders ended with the \
                    tree dirty again. A body reads state; a handler writes it. \
                    The pending change was dropped to stop the render loop.
                    """))
            }
        } else {
            selfDirtied = 0
        }

        let wire = Wire.encode(
            result.patch,
            generation: generation,
            complete: describeAll,
            dictionary: wireDictionary)

        // After the encode: what is in these bytes is what the host will fly,
        // and everything else the render was offered is answered here.
        settle(offered: offered, carried: differ.takeCarried())

        // QUEUED, not started: `start` would run the handler here and now,
        // inside the host's render call - and a state write it makes would
        // land after the host's "does anything need rendering" look, waiting
        // for the next event to be drawn. Measured, in the gallery: three
        // slider steps, two log lines, the third sitting in state until the
        // next touch. A queued job takes the path every resumed handler
        // takes - the waker tells the host, the drain runs the job, and the
        // drain ends in a Pump, which renders what the handler wrote. That
        // also keeps author code out of the render call entirely.
        //
        // AFTER the clear above either way: a write from one of these must ask
        // for the NEXT render, not be wiped by this one's bookkeeping. See
        // Core/Changes.swift.
        for handler in differ.takeFired() {
            queue(handler)
        }

        return wire
    }

    /// The whole tree, the styles to resolve it against, and how its values
    /// travel when they change.
    ///
    /// Read together, inside one `ReadScope`, because they are one build: the
    /// styles may be answered from state - the gallery's are, its SearchBar
    /// style asking the idiom - and a change to that state must take the same
    /// road a change to the window does. Whatever they read lands in
    /// `rootReads`, which is what keeps the clean walk from carrying controls
    /// past a sheet that has moved under them.
    private var root: (tree: Node, styles: StyleSheet?, motion: Motion) {
        guard let application = application else {
            return (Renderer.unregistered, nil, .standard)
        }

        // The APPLICATION is the root and its windows are an arranged children
        // list - one window for most applications, several for a desktop one.
        // The host opens and closes to match it, so a window that leaves this
        // list is a window that closes. See `windows` in Views/Application.swift.
        var node = Node(type: .application, children: application.windows.map(\.body))

        // The one thing an application HEARS: the reader asking the platform
        // for a window of its own. It is the root's own handler rather than any
        // window's, because the answer is a change to the window LIST.
        if let creating = application.onCreatingWindow {
            node.addHandler(.creatingWindow) {
                try await creating()

                // "No" IS an answer, and the host is holding a blank window
                // until it hears one: a handler that describes no new window
                // would otherwise leave the tree unchanged, make no message,
                // and the window the reader asked for would stand there empty.
                // The message this asks for carries the window list, and a
                // list with nothing new in it is what closes it again.
                Renderer.shared.setNeedsRender()
            }
        }

        return (node, application.styles, application.motion)
    }

    /// The handler the application answers the platform's window request with,
    /// as the tree carries it - the author's own closure and the ask for a
    /// render that follows it, which is what an answer of "no" is made of.
    /// Nil for an application that hears nothing.
    var creatingWindowHandler: EventHandler? { root.tree.events[.creatingWindow] }

    /// Shown until an application registers itself, in the same shape a real one
    /// produces so the host has one thing to read.
    private static var unregistered: Node {
        Node(type: .application, children: [
            Node(type: .window, children: [
                Node(type: .contentPage, children: [
                    Node(type: .label, props: [
                        .text: .string("StateUI: no application registered")
                    ])
                ])
            ])
        ])
    }

    /// Queues an act - a token, whether the library's or an application's;
    /// the session dictionary numbers both the same way.
    func send(_ act: Act, _ arguments: [PropValue], completion: ((Reply) -> Void)?) {
        enqueue({ Command(act: act, arguments: arguments, completion: $0) }, completion)
    }

    /// Queues an act for the host - see Command.swift.
    ///
    /// Callable from any thread: a child task started with `async let` sends
    /// from the cooperative pool, which is why the registry is behind `guarded`.
    private func enqueue(_ command: (Int?) -> Command, _ completion: ((Reply) -> Void)?) {
        guarded.sync {
            var id: Int?

            if let completion = completion {
                id = nextCompletionId
                completions[nextCompletionId] = completion
                nextCompletionId -= 1
            }

            commands.append(command(id))
        }

        // The wake, outside the lock: an act queued from a plain `Task` runs
        // on the pool and lands no job on the executor, so nothing else would
        // tell the host this command exists - it would sit in the queue until
        // the next event, a pressed card never coming back up. Coalesced by
        // the waker's own armed flag, so a burst of sends is one wake.
        MainThreadExecutor.shared.poke()
    }

    /// Flights an author has started that no message has carried yet.
    ///
    /// Keyed by the state they are about, so a second `animateTo` on the same
    /// state REPLACES the first rather than racing it - the older one is
    /// answered false on the spot, never left waiting for a walk that will not
    /// happen. Behind `guarded` because `isFlying` asks from wherever a
    /// two-way input's report arrives, and `offeredFlights` from the render.
    private var flying: [FlightKey: PendingFlight] = [:]

    /// Starts a flight: registers what it will report on, hands the state its
    /// target, and suspends until the host says it landed.
    ///
    /// A flight queues NO command. What carries it is the ordinary render that
    /// the state write asks for - the differ finds the properties armed on
    /// this state among the ones that changed and writes a transition beside
    /// each - which is why this is the one thing that takes a completion id
    /// without going through `enqueue`.
    ///
    /// Isolated to `@MainThread`, whoever calls: a handler is there already
    /// and pays nothing, while a child task started with `async let` - which
    /// runs on the cooperative pool, by Swift's design - hops here first.
    /// That hop is what makes booking and committing ONE synchronous stretch
    /// on the thread that renders, and it buys three things at once. Two
    /// flights on one state cannot interleave, so the flight that answers
    /// true is always the one whose target the state holds. The write lands
    /// on the one thread every other state write lands on, beside no render.
    /// And the hop's own job is the wake: the drain that runs it ends in the
    /// host's render, so no separate poke has to race the write it announces.
    @MainThread func fly(
        _ key: FlightKey,
        motion: Motion,
        every interval: UInt32,
        plan: FlightPlan
    ) async throws -> [PropValue] {
        var channel: Int32 = 0

        // Whatever the flight answers - landed, superseded, stopped - nobody is
        // listening afterwards, and a report arriving late must find nothing
        // rather than write into a state the author has moved on from.
        //
        // The WALK goes with it. An entry left in `flown` makes a state that
        // has ever been flown read as flying for the rest of the session,
        // which is invisible to `stop()` - it would name a channel the host
        // has already finished with, and nothing comes back - and a real fault
        // to a two-way input, which asks the same question to decide whether
        // to write a report back: a slider flown once would ignore every drag
        // afterwards. Only while it is still THIS flight's, the guard `settle`
        // makes for the same reason.
        defer {
            if channel != 0 {
                guarded.sync {
                    _ = reports.removeValue(forKey: channel)

                    if flown[key] == channel {
                        flown.removeValue(forKey: key)
                    }
                }
            }
        }

        return try await answered { completion in
            channel = self.begin(
                key, motion: motion,
                every: interval, reporting: plan.reporting,
                lender: plan.lender, completion: completion)

            // After the flight is on the books, never before: the render this
            // write asks for has to find it, or the property would cross as a
            // plain change and snap.
            plan.commit()
        }
    }

    /// Books a flight, answers the CHANNEL it was given, and resolves the one
    /// it displaced if it displaced one.
    private func begin(
        _ key: FlightKey,
        motion: Motion,
        every interval: UInt32,
        reporting: ((PropValue) -> Void)?,
        lender: AnyObject,
        completion: @escaping (Reply) -> Void
    ) -> Int32 {
        var channel: Int32 = 0

        let superseded: ((Reply) -> Void)? = guarded.sync {
            let id = nextCompletionId
            channel = Int32(id)
            completions[id] = completion
            nextCompletionId -= 1

            if let reporting = reporting {
                reports[channel] = reporting
            }

            let older = flying.updateValue(
                PendingFlight(
                    motion: motion,
                    channel: channel, report: interval, lender: lender),
                forKey: key)

            if let older = older {
                reports.removeValue(forKey: older.channel)
            }

            return older.flatMap { completions.removeValue(forKey: Int($0.channel)) }
        }

        // Outside the lock, for the reason `dispatch` gives: a resume runs
        // machinery that must not find it held. FALSE, deliberately - the walk
        // this flight would have made never happened, and only a flight that
        // genuinely had nothing to do answers true.
        superseded?(.finished([.bool(false)]))

        return channel
    }

    /// Where a walk's progress is written, by the channel the host reports on.
    ///
    /// Entered when a flight is booked and dropped the moment it answers, so a
    /// report that crosses while the handler is being resumed finds nothing and
    /// does nothing - the last word about where the walk ended belongs to the
    /// flight's own answer, not to a sample.
    private var reports: [Int32: (PropValue) -> Void] = [:]

    /// A sample the host sent for a walk in the air: what the control is
    /// showing right now, written into whatever state the author asked to
    /// watch it with.
    ///
    /// Answers whether anybody was listening. Nobody is the ordinary case for a
    /// report that arrives a frame after the flight was stopped, and it is not
    /// an error - see `stateui_report_flight`.
    @discardableResult
    func reported(_ channel: Int32, _ value: PropValue) -> Bool {
        guard let write = guarded.sync(execute: { reports[channel] }) else { return false }

        write(value)
        return true
    }

    /// The channels the HOST is flying, by the state each is about.
    ///
    /// Written when a render hands a flight over and left there afterwards:
    /// a channel is never reused - the counter only goes down - so an entry
    /// that outlives its flight names a channel the host has forgotten, and
    /// asking to stop it answers nothing and writes nothing.
    private var flown: [FlightKey: Int32] = [:]

    /// The channel a flight on this state is being flown on, if one is.
    func flownChannel(for key: FlightKey) -> Int32? {
        guarded.sync { flown[key] }
    }

    /// The flights a render is to look for, taken once so the walk itself
    /// touches no lock.
    func offeredFlights() -> [FlightKey: PendingFlight] {
        guarded.sync { flying }
    }

    /// The states written with `snap(to:)` since the last render.
    ///
    /// A write, not a setting: what is taken here is spent on the render that
    /// takes it, and the next assignment to the same state travels again.
    private var snapping: Set<FlightKey> = []

    /// Marks the next change to this state as one that lands at once.
    func snap(_ key: FlightKey) {
        guarded.sync { _ = snapping.insert(key) }
    }

    /// The snapped states a render is to look for, taken and spent.
    func offeredSnaps() -> Set<FlightKey> {
        guarded.sync {
            let taken = snapping
            snapping.removeAll()
            return taken
        }
    }

    /// Closes the books on the flights a render was offered: the ones it
    /// carried are the host's now, and the ones no property claimed are
    /// answered here, because nothing else ever will.
    ///
    /// A flight nothing claimed is one whose state moved to where it already
    /// was, or whose armed control is not on screen. Both are TRUE: the answer
    /// says the model is where it was going, not that a glide was drawn.
    func settle(
        offered: [FlightKey: PendingFlight],
        carried: Set<FlightKey>
    ) {
        guard !offered.isEmpty else { return }

        // In channel order rather than the dictionary's, which Swift salts
        // per instance: two handlers resumed in one settle must be resumed in
        // the same order in every run.
        let stranded: [(Reply) -> Void] = guarded.sync {
            var taken: [(channel: Int32, completion: (Reply) -> Void)] = []

            for (key, flight) in offered {
                // Only while it is still the same flight: one that took its
                // place has already answered for it.
                guard flying[key]?.channel == flight.channel else { continue }
                flying.removeValue(forKey: key)

                if carried.contains(key) {
                    // Handed over: this is the channel to name when the author
                    // asks for the walk to stop where it stands.
                    flown[key] = flight.channel
                }

                guard !carried.contains(key),
                    let completion = completions.removeValue(forKey: Int(flight.channel))
                else { continue }

                taken.append((flight.channel, completion))
            }

            return taken.sorted { $0.channel > $1.channel }.map { $0.completion }
        }

        for completion in stranded {
            completion(.finished([.bool(true)]))
        }
    }

    /// How many acts are queued and not yet taken.
    ///
    /// What `stateui_wait_work` adds to the job count, so a wake that
    /// announced a COMMAND - `poke`, no job anywhere - still reads as work
    /// to the host's parked thread.
    var commandsPending: Int { guarded.sync { commands.count } }

    /// Queues an act and suspends until the host reports what came of it.
    ///
    /// `nonisolated(nonsending)` so that it runs - and resumes - on the executor
    /// of whoever called it, which for a handler is `@MainThread`. Written as a
    /// plain async function it would run on Swift's cooperative pool, and the
    /// caller would come back to life beside a C# render.
    ///
    /// Returns the VALUES the act came to, already typed - `focus` reads one
    /// bool, the clock reads its numbers - and throws `StateUIError` with
    /// the host's reason when it could not be performed. Nothing is parsed:
    /// the reply crossed as tagged values, see `Wire.decodeReply`.
    nonisolated(nonsending) func call(
        _ act: Act,
        _ arguments: [PropValue] = []
    ) async throws -> [PropValue] {
        try await answered { self.send(act, arguments, completion: $0) }
    }

    /// The suspension itself: queues through `send`, waits for the reply, and
    /// turns its two arms into a return and a throw.
    private nonisolated(nonsending) func answered(
        _ send: (@escaping (Reply) -> Void) -> Void
    ) async throws -> [PropValue] {
        let reply = await withCheckedContinuation { (continuation: CheckedContinuation<Reply, Never>) in
            send { outcome in
                // Counted here and lowered on the line below, which is the first
                // thing that runs on the other side of the suspension - so the
                // host can tell "the resume has not landed yet" from "there is
                // nothing to wait for".
                Renderer.shared.guarded.sync { Renderer.shared.resumes += 1 }
                continuation.resume(returning: outcome)
            }
        }

        // On a pool thread when the caller was a child task, hence the lock.
        guarded.sync { resumes -= 1 }

        switch reply {
        case .finished(let values):
            return values
        case .failed(let message):
            throw StateUIError(message: message)
        }
    }

    /// Reports a handler that threw, so that a failed `try await` is visible
    /// rather than lost.
    ///
    /// Goes out as an ordinary command, which means it reaches the host on the
    /// same path everything else does and needs nothing new on the boundary.
    func report(_ error: Error) {
        send(.handlerFailed, [.string(String(describing: error))], completion: nil)
    }

    /// Hands the queued acts to the host and forgets them - keeping a RECEIPT:
    /// the completion ids of exactly this batch, so a batch the host cannot
    /// read can be failed back by id. See `failTakenCommands`.
    ///
    /// The take is atomic against a child task's `send`; the encoding happens
    /// outside the lock, having nothing shared left to read. The receipt is
    /// overwritten by every take, an empty one included: takes and the host's
    /// parse run in order on the one thread, so by the time a batch is taken
    /// the previous one has either been performed or already failed back.
    ///
    /// An empty queue answers an empty array, and the export hands the host a
    /// null pointer for it - the common case, every pump, allocating nothing.
    func takeCommandsWire() -> [UInt8] {
        // The saves waiting for a store, made into acts HERE rather than at
        // the write: a key written five times between two takes is one act
        // holding the last value, which is what keeps an Entry bound to kept
        // state from saving once per letter. Sorted by name inside the store,
        // the determinism rule.
        //
        // Nothing has to wake the host for these. A persistent write is a
        // state write first, so the render it asks for is already coming, and
        // the acts are drained after every render.
        let saves = PersistentStore.shared.takeWaiting().map {
            Command(act: .persistValue, arguments: [.name($0.name), $0.value], completion: nil)
        }

        let queued = guarded.sync {
            let queued = commands
            commands.removeAll(keepingCapacity: true)
            takenCompletions = queued.compactMap { $0.completion }
            return queued
        }

        let batch = queued + saves

        return batch.isEmpty ? [] : Wire.encode(batch, dictionary: wireDictionary)
    }

    /// Which store the application keeps state in, and every key it keeps
    /// there - what the host hydrates from before the first render.
    ///
    /// Empty for an application that keeps nothing, which is most of them: the
    /// host then reads no store and crosses nothing back. See
    /// Core/Persistence.swift.
    func persistentWire() -> [UInt8] {
        guard let application, !application.persistentKeys.isEmpty else { return [] }

        return Wire.encodePersistent(
            storage: application.persistentStorage,
            keys: application.persistentKeys)
    }

    /// Fails every act of the last taken batch, because the host could not
    /// read it.
    ///
    /// The batch is already OFF the queue and its completion ids are inside
    /// the very bytes that would not read - only this side still knows them.
    /// Each one goes through the ordinary reply path with `-` and the reason,
    /// so an awaiting handler resumes by THROWING instead of staying suspended
    /// forever with nothing anywhere saying why. Deliberately not a timeout:
    /// an act may wait unboundedly and legitimately - a dialog waits for the
    /// reader - so the failure is causal, told by the side that failed.
    ///
    /// The receipt is taken and cleared first, so calling this twice fails
    /// nobody twice - and an act performed normally in the meantime is safe
    /// either way, `dispatch` answering false for a completion already gone.
    func failTakenCommands(_ reason: String) {
        let ids = guarded.sync {
            let ids = takenCompletions
            takenCompletions = []
            return ids
        }

        for id in ids {
            // The same two steps the export takes for a reply from the host -
            // the buffer carries the outcome, dispatch resumes the handler.
            ReplyBuffer.current = .failed(reason)
            _ = dispatch(id)
        }
    }

    /// Runs the closure an id refers to: an element's event handler, or the
    /// continuation waiting for an act when the id is negative.
    ///
    /// Returns false when the id is unknown, which happens for an event arriving
    /// against an element that has left the tree, and for an act that has already
    /// been reported. Ignoring it is correct; crashing would not be.
    ///
    /// A handler runs inside a `Task` on `@MainThread`, which is what gives it
    /// somewhere to suspend. That costs nothing when it does not: the executor
    /// hands the task straight back to the host, the host is already on its own
    /// thread, and the whole handler runs before this returns. Only a handler
    /// that really awaits comes back later, and it comes back on the same
    /// thread.
    ///
    /// The Bool therefore says a handler was FOUND, not that it has finished.
    func dispatch(_ handlerId: Int) -> Bool {
        if handlerId < 0 {
            // Removed under the lock, invoked outside it: the completion resumes
            // a continuation, and Swift may run part of that machinery here and
            // now - none of which may find the lock held.
            let taken = guarded.sync { completions.removeValue(forKey: handlerId) }

            guard let completion = taken else { return false }
            completion(ReplyBuffer.current)

            // Nothing is run here on purpose. `resume()` schedules the rest of
            // the handler rather than continuing it, and the job it produces
            // does not exist yet - measured. Looking for it now would find
            // nothing and suggest that it might, which is the one thing the
            // host's retry exists to say it does not.
            return true
        }

        // The differ holds these: they belong to elements, and an element that
        // was skipped this render still has to answer for its buttons.
        guard let handler = differ.handler(handlerId) else { return false }

        start(handler)
        return true
    }

    /// Runs a handler the way a dispatched event does.
    ///
    /// The one place a handler is ever started, so that a test exercises the
    /// same path an event does rather than a copy of it - the difference matters
    /// here, since what is under test is precisely WHERE the closure runs.
    func start(_ handler: @escaping EventHandler) {
        // Read here rather than inside the task: the buffer holds the payload of
        // the event being dispatched RIGHT NOW, and a handler that suspends would
        // otherwise read whatever the next event left there.
        let payload = EventBuffer.current
        let carried = CarriedHandler(run: handler)

        Task { @MainThread in
            EventBuffer.current = payload

            do {
                try await carried.run()
            } catch {
                Renderer.shared.report(error)
            }
        }

        // `Task` queues its first job on the calling thread, synchronously -
        // measured - so this runs the handler here and now, up to its first
        // suspension. That is what keeps a handler with no `await` in it
        // finishing before the event returns to the host.
        stateUIRunJobs()
    }

    /// Starts a handler the way `start` does, but leaves it QUEUED for the
    /// host's next drain rather than running it here and now.
    ///
    /// For a handler discovered MID-RENDER - `.onChanged` - where running it at
    /// once would mean author code executing inside the host's render call,
    /// and a state write landing after the host's "does anything need
    /// rendering" look. Queued, it takes the path a resumed handler takes:
    /// enqueueing signals the waker, the drain runs the job, and the drain
    /// ends in a Pump - so what the handler writes is rendered without
    /// anything new on the boundary. No payload is carried: the events that
    /// have one run through `start`, from a dispatch that just wrote it.
    func queue(_ handler: @escaping EventHandler) {
        let carried = CarriedHandler(run: handler)

        Task { @MainThread in
            do {
                try await carried.run()
            } catch {
                Renderer.shared.report(error)
            }
        }
    }
}

/// Carries a handler into the task that runs it.
///
/// The handler lives in the differ's registry, which the compiler reads as
/// shared state - so handing one to a `Task` is a region violation on paper. It
/// is not one here: the task is isolated to `@MainThread`, the registry is only
/// ever touched from there, and there is one such thread. The same
/// `@unchecked Sendable` promise the Renderer itself is built on, made in the
/// one place that needs it rather than by loosening the handler type for
/// everyone - a `@Sendable` EventHandler would stop an author capturing their
/// own state in a closure, which is what handlers are for.
private struct CarriedHandler: @unchecked Sendable {
    let run: EventHandler
}

/// Holds the payload of the event currently being dispatched - the typed
/// values the control reported, one per property of the MAUI EventArgs, in
/// the order MAUI declares them.
///
/// Keeping it in a side channel avoids widening the P/Invoke surface: the
/// dispatch entry point takes an id plus one byte buffer, instead of needing
/// a variant per event shape. An Entry's textChanged handler reads its new
/// text from here; a pan handler reads its status and totals. A handler that
/// suspends keeps the payload it started with - `Renderer.start` carries it
/// into the task - so the next event cannot swap it mid-handler.
enum EventBuffer {
    // nonisolated(unsafe): written and read only during a single event
    // dispatch, on the UI thread - see the note on Renderer.shared.
    nonisolated(unsafe) static var current: [PropValue] = []
}

/// Holds the outcome of the act currently being reported - the reply the
/// dispatch entry decoded, read by the completion `Renderer.dispatch` resumes.
///
/// A separate buffer from `EventBuffer` because the two shapes are different
/// things: an event carries values and nothing else, an outcome is values OR
/// a reason it failed. One buffer holding both would make every reader ask
/// which kind it is holding.
enum ReplyBuffer {
    // nonisolated(unsafe): written and read only during a single completion
    // dispatch, on the UI thread - see the note on Renderer.shared.
    nonisolated(unsafe) static var current: Reply = .finished([])
}
