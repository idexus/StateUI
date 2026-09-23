// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The renderer: it holds the application, knows what changed since the last
// render, and renders the patch a host applies - typed for a Swift host, as
// Wire bytes for a runtime in another language.
// Design: docs/design/core/render.md#one-renderer

/// The one renderer: it holds the application and renders what changed for
/// the host, which calls in from the thread it draws on.
public final class Renderer: @unchecked Sendable {
    // Entered only from the host's UI thread, synchronously, so it is not isolated.
    // Design: docs/design/core/render.md#one-renderer

    /// The one renderer: a process has one host.
    public static let shared = Renderer()

    private var application: Application?
    private var dirty = true

    /// The states written since the last render, by storage identity. Behind
    /// `guarded`: a write may come from any thread.
    private var changed: Set<ObjectIdentifier> = []

    /// What each changed state is called, for `debugInfo()` and an inspector.
    private var names: [ObjectIdentifier: String] = [:]

    /// Whether a render was asked for without naming a state, which makes the next
    /// render build the whole tree.
    private var untracked = true

    /// What the last root build read outside every element; a change to any of it
    /// builds the application again.
    /// Design: docs/design/core/render.md#three-roads
    private var rootReads: Set<ObjectIdentifier> = []

    /// How many live elements read each state, by storage identity. A write to a
    /// state nobody reads asks for nothing. Behind `guarded`.
    /// Design: docs/design/core/invalidation.md#live-readers
    private var readers: [ObjectIdentifier: Int] = [:]

    /// Whether a render is running: every write then goes on the books unasked.
    /// Design: docs/design/core/invalidation.md#writes-during-a-render
    private var rendering = false

    /// How many renders there have been - the tally's count.
    /// Design: docs/design/core/diagnostics.md#the-tally
    private(set) var renders = 0

    /// How many renders carried no patch - the tally's `empty`.
    private(set) var emptyRenders = 0

    /// How many writes asked for nothing because no live element read the state -
    /// the tally's `refused`.
    private(set) var refusedWrites = 0

    /// How many rendered nodes are alive - the tally's `alive`.
    private(set) var liveNodes = 0

    func nodeBorn() {
        guarded.withLock { liveNodes += 1 }
    }

    func nodeGone() {
        guarded.withLock { liveNodes -= 1 }
    }

    private let differ = Differ()

    /// This session's numbering of the names the wire carries (Core/Wire.swift).
    private let wireDictionary = WireDictionary()

    /// The tree as the host is showing it, as far as this side knows.
    private var rendered: RenderedNode?

    /// Which render produced `rendered`. A host quoting any other generation gets
    /// the whole tree.
    /// Design: docs/design/core/render.md#generations-and-baseline
    private var generation: Int32 = 0

    /// How many renders in a row ended with the tree dirty again.
    private var selfDirtied = 0

    /// The streak that reads as a body writing the state it reads.
    /// Design: docs/design/core/render.md#self-dirtying-renders
    static let selfDirtyLimit = 16

    /// How many settle passes a render runs before its message leaves.
    /// Design: docs/design/core/render.md#handlers-in-the-message
    static let settleLimit = 3

    /// Guards what a pool thread can reach: the change bookkeeping, the readers, the
    /// act queue and the completions. What is taken out runs after it is released.
    /// Design: docs/design/core/render.md#one-renderer
    private let guarded = Lock()

    /// Acts waiting for the host to take them (Core/ActCall.swift).
    private var actCalls: [ActCall] = []

    /// Continuations waiting for an act or an animation to finish, by negative id.
    /// Design: docs/design/core/acts.md#completion-ids
    private var completions: [Int: (Reply) -> Void] = [:]
    private var nextCompletionId = -1

    /// The completion ids of the last batch taken - its receipt. Behind `guarded`.
    /// Design: docs/design/core/acts.md#the-receipt
    private var takenCompletions: [Int] = []

    /// Resumes reported by the host that have not come back yet. Behind `guarded`.
    private var resumes = 0

    /// How many handlers were told their act is over and have not run a line since;
    /// a test waits on it for a queue gone quiet.
    /// Design: docs/design/core/acts.md#awaiting-an-answer
    var resumesPending: Int { guarded.withLock { resumes } }

    /// Installs the UI thread's executor before anything here starts a task.
    /// Design: docs/design/core/concurrency.md#mainactor-on-every-platform
    private init() {
        UIThreadExecutor.install()
    }

    /// Registers the application. Called through `stateUIUseApp`.
    ///
    /// - Parameter application: the application, made once what an earlier
    ///   registration wrote into the application's session is forgotten.
    public func setApplication(_ application: @autoclosure () -> Application) {
        StandardEnvironment.application.forget()

        // A new application is a new tree: the old one is let go, and every element of
        // this one arrives.
        // Design: docs/design/core/render.md#a-new-application
        if let rendered {
            differ.forget(rendered)
            self.rendered = nil
        }

        unreading(rootReads)
        rootReads = []

        let application = application()
        self.application = application
        Renderer.name(statesOf: application)

        // One scene, waiting for the platform's first window (Core/Scenes.swift).
        Scenes.shared.reset()

        setNeedsRender()
    }

    /// Names the application's own `@State` by their properties, once, since the
    /// application is never walked like a view.
    static func name(statesOf application: Application) {
        for child in Mirror(reflecting: application).children {
            if let label = child.label, let box = child.value as? StateBox {
                box.named(label)
            }
        }
    }

    /// Asks for a render without naming what changed, so the next render builds
    /// the whole tree. Safe from any thread; it wakes the host.
    public func setNeedsRender() {
        guarded.withLock {
            dirty = true
            untracked = true
        }

        // Outside the lock: the executor's lock is never taken inside this one.
        UIThreadExecutor.shared.poke()
    }

    /// Records that a state was read. While a view is built, the view becomes
    /// its reader; anywhere else it costs nearly nothing.
    ///
    /// - Returns: whether a build was open to record it.
    @discardableResult
    public func stateRead(_ state: AnyObject) -> Bool {
        ReadScope.note(ObjectIdentifier(state))
    }

    /// Records that a state was written and asks for a render that rebuilds only
    /// the views that read it. A state no live element reads asks for nothing.
    /// Safe from any thread; it wakes the host.
    public func stateChanged(_ state: AnyObject) {
        let id = ObjectIdentifier(state)

        // Named while the object is in hand: a `@State` knows its property, anything
        // else is called by its type.
        let name = (state as? NamedState)?.origin

        let asked: Bool = guarded.withLock {
            guard rendering || readers[id] != nil else {
                refusedWrites += 1
                return false
            }

            dirty = true
            changed.insert(id)

            if let name = name {
                names[id] = name
            } else if names[id] == nil {
                names[id] = String(describing: type(of: state))
            }

            return true
        }

        if asked {
            UIThreadExecutor.shared.poke()
        }
    }

    /// Counts one more live reader of each state - an element as it is made, or
    /// the root build.
    func reading(_ states: Set<ObjectIdentifier>) {
        guarded.withLock {
            for id in states {
                readers[id, default: 0] += 1
            }
        }
    }

    /// Counts one reader fewer of each state - the element that read them has gone.
    func unreading(_ states: Set<ObjectIdentifier>) {
        guarded.withLock {
            for id in states {
                guard let count = readers[id] else { continue }

                readers[id] = count > 1 ? count - 1 : nil
            }
        }
    }

    /// Whether any live element reads this state - what a test asks.
    func isRead(_ state: AnyObject) -> Bool {
        guarded.withLock { readers[ObjectIdentifier(state)] != nil }
    }

    // MARK: - Continuous values

    /// One board per sync; the display's frame is the only sync.
    /// Design: docs/design/core/cycle.md#the-board
    private let boards: [CycleBoard] = [CycleBoard(sync: .display)]

    /// The board a value belongs to.
    func board(of storage: HostStorage) -> CycleBoard { boards[storage.board] }

    /// The board one clock's cycles run on.
    func board(for sync: Sync) -> CycleBoard {
        boards.first { $0.sync == sync } ?? boards[0]
    }

    /// Forgets an engine on every board - what an element leaving the tree owes.
    func disarm(_ id: Int) {
        for board in boards {
            board.disarm(id)
        }
    }

    /// Every state issued a number, held weakly: a storage belongs to its view.
    private var states: [Int32: () -> HostStorage?] = [:]

    /// The next state number. Never zero, which `cycleRead` reads as "every state".
    private var nextNumber: Int32 = 1

    /// The number the host quotes this value by, issued once and kept on it.
    /// Design: docs/design/core/cycle.md#state-numbers
    func number(for storage: HostStorage) -> Int32 {
        if let issued = storage.number { return issued }

        let issued = nextNumber
        nextNumber += 1
        storage.number = issued

        guarded.withLock {
            states[issued] = { [weak storage] in storage }
        }

        return issued
    }

    /// Reads one state attachment for a Swift host: the whole image, or nil for an
    /// inward-only, stale or orphaned attachment.
    func hostValue(for binding: HostStateBinding) -> HostStateValue? {
        guard binding.mode != .in,
              let storage = storage(of: binding.state),
              storage.door == binding.kind,
              let bytes = board(of: storage).whole(binding.state)
        else { return nil }

        return StateImage.carried(
            of: bytes,
            lanes: binding.kind == .text ? 0 : StateValueLanes.own)
    }

    /// The first lane of a state a native gesture names by its number, which the
    /// gesture carries on the view.
    func hostGestureValue(state: Int32) -> Double? {
        guard let storage = storage(of: state),
              let bytes = board(of: storage).whole(state),
              case .lanes(let lanes) = StateImage.carried(
                of: bytes, lanes: StateValueLanes.own)
        else { return nil }

        return lanes.first
    }

    /// Writes a gesture's one lane before the host runs the cycle. Keyed by state
    /// number: `panX` and `panY` feed an engine without driving a property.
    func hostMovedGesture(_ value: Double, state: Int32) -> Bool {
        guard value.isFinite, let storage = storage(of: state) else { return false }

        let mask: UInt64 = 1
        board(of: storage).told(
            StateImage.bytes(of: .lanes([value])),
            mask: mask,
            to: storage)
        storage.told?(mask)
        storage.sampleTaken()
        return true
    }

    /// Takes one native control's report into the state's image, for a Swift host.
    /// Text crosses whole and plain values and feeds name every lane; an animated
    /// property reports through its journey instead.
    func hostReported(
        _ value: HostStateValue,
        through binding: HostStateBinding
    ) -> Bool {
        guard binding.mode != .out,
              binding.kind == .text || binding.kind == .plain || binding.kind == .feed,
              let storage = storage(of: binding.state),
              storage.door == binding.kind
        else { return false }

        let mask: UInt64

        switch (binding.kind, value) {
        case (.text, .text):
            mask = ~0

        case (.plain, .lanes(let lanes)), (.feed, .lanes(let lanes)):
            let expected = board(of: storage).read(storage, lanes: StateValueLanes.own)

            guard case .lanes(let current) = expected, current.count == lanes.count else {
                return false
            }

            mask = Self.laneMask(lanes.count)

        default:
            return false
        }

        let board = board(of: storage)
        board.told(StateImage.bytes(of: value), mask: mask, to: storage)

        // After the board has let go: both callbacks may take this renderer's lock.
        storage.told?(mask)
        storage.sampleTaken()
        return true
    }

    /// Takes the parts of a journey a native animation changed; the law, the waiter
    /// and the stop count stay the state's. Reported lanes are never echoed back.
    /// Design: docs/design/core/cycle.md#what-the-host-reports
    func hostReported(
        _ journey: HostJourney,
        updating update: HostJourneyUpdate,
        through binding: HostStateBinding
    ) -> Bool {
        guard binding.mode != .out,
              binding.kind == .property,
              !update.isEmpty,
              let storage = storage(of: binding.state),
              storage.door == binding.kind,
              let bytes = board(of: storage).whole(binding.state)
        else { return false }

        let current = StateImage.carried(of: bytes, lanes: StateValueLanes.own)
        guard let standing = StateUIHost.journey(from: current),
              journey.value.count == standing.value.count,
              journey.destination.count == standing.destination.count,
              journey.velocity.count == standing.velocity.count,
              journey.value.allSatisfy(\.isFinite),
              journey.destination.allSatisfy(\.isFinite),
              journey.velocity.allSatisfy(\.isFinite)
        else { return false }

        let width = standing.value.count
        var lanes = standing.value
            + standing.destination
            + standing.velocity
            + StateLaw.lanes(of: standing.motion)
            + [Double(standing.completion ?? 0), Double(standing.stopped)]
        var mask: UInt64 = 0

        func replace(_ values: [Double], at start: Int) {
            for (offset, value) in values.enumerated() {
                lanes[start + offset] = value
                mask |= HostStorage.bit(of: start + offset)
            }
        }

        if update.contains(.value) { replace(journey.value, at: 0) }
        if update.contains(.destination) { replace(journey.destination, at: width) }
        if update.contains(.velocity) { replace(journey.velocity, at: width * 2) }

        let board = board(of: storage)
        board.told(StateImage.bytes(of: .lanes(lanes)), mask: mask, to: storage)
        storage.told?(mask)
        storage.sampleTaken()
        return true
    }

    /// Runs one board's cycle and takes the typed values it published.
    func hostCycle(sync: Sync, now: Double, reducesMotion: Bool) -> HostCycle {
        let board = board(for: sync)
        let report = board.cycle(now: now, reducesMotion: reducesMotion)
        let changes = board.dirty().compactMap { entry -> HostStateChange? in
            guard let storage = storage(of: entry.number), let kind = storage.door else {
                return nil
            }

            return HostStateChange(
                state: entry.number,
                changed: entry.mask,
                value: StateImage.carried(
                    of: entry.bytes,
                    lanes: kind == .text ? 0 : StateValueLanes.own))
        }

        return HostCycle(changes: changes, continues: report.awake)
    }

    /// A mask naming `count` lanes, including values wider than one word.
    private static func laneMask(_ count: Int) -> UInt64 {
        if count >= 64 { return ~0 }
        if count <= 0 { return 0 }
        return (UInt64(1) << UInt64(count)) - 1
    }


    /// Takes in a batch of state writes from the host, in `StateBatch`'s layout.
    ///
    /// - Returns: how many states were written, or -1 where the bytes ran out.
    func cycleWritten(_ batch: UnsafeBufferPointer<UInt8>) -> Int {
        let (writes, complete) = StateBatch.decode(batch)
        var written = 0

        for write in writes {
            guard let storage = storage(of: write.number) else { continue }

            board(of: storage).told(write.bytes, mask: write.mask, to: storage)

            // After the board has let go: the state's hook may take this renderer's lock.
            storage.told?(write.mask)

            // Readings asked for with `.samples` see every host write (Core/Sampling.swift).
            storage.sampleTaken()
            written += 1
        }

        return complete ? written : -1
    }

    /// Runs one cycle of one board.
    ///
    /// - Returns: how many states have lanes waiting, with `0x4000_0000` set where
    ///   an engine has more to do; -1 for no such board.
    func cycle(sync: Int32, now: Double, reducesMotion: Bool) -> Int32 {
        guard sync >= 0, Int(sync) < boards.count else { return -1 }

        let report = boards[Int(sync)].cycle(now: now, reducesMotion: reducesMotion)

        return Int32(report.written.count) | (report.awake ? 0x4000_0000 : 0)
    }

    /// Reads out what a cycle wrote, in `cycleWritten`'s layout: number 0 for every
    /// state waiting, or one state whole. Answers the bytes written, 0 for a number
    /// that has gone, or -1 where the buffer is too small and nothing was cleared.
    func cycleRead(_ number: Int32, into out: UnsafeMutableBufferPointer<UInt8>) -> Int {
        var batch: [(number: Int32, mask: UInt64, bytes: [UInt8])] = []

        if number == 0 {
            for board in boards {
                batch += board.dirty()
            }

            batch.sort { $0.number < $1.number }
        } else if let storage = storage(of: number), let bytes = board(of: storage).whole(number) {
            batch = [(number, ~0, bytes)]
        } else {
            return 0
        }

        let bytes = StateBatch.encode(batch.map {
            StateBatch.Write(number: $0.number, mask: $0.mask, bytes: $0.bytes)
        })

        guard bytes.count <= out.count else {
            // `dirty()` already cleared its bits, so they are put back and the call can be
            // made again with room.
            for entry in batch where number == 0 {
                if let storage = storage(of: entry.number) {
                    board(of: storage).told([], mask: 0, to: storage)
                    storage.dirty |= entry.mask
                }
            }

            return -1
        }

        for index in 0..<bytes.count {
            out[index] = bytes[index]
        }

        return bytes.count
    }

    /// How many boards have anything waiting for a cycle.
    func cycleAwake() -> Int32 {
        Int32(boards.filter { $0.awake }.count)
    }

    /// The last cycle of every board as one line, built only when the host traces.
    func cycleTrace() -> String {
        boards.enumerated().map { index, board in
            let report = board.reported

            return "cycle \(index) latched=\(report.latched) ran=\(report.ran)"
                + " skipped=\(report.skipped) wrote=\(report.written.count)"
                + " awake=\(report.awake ? 1 : 0)"
        }.joined(separator: " | ")
    }

    /// A state by its number, or nil where none rides it any more.
    func storage(of number: Int32) -> HostStorage? {
        let found = guarded.withLock { states[number] }

        guard let storage = found?() else {
            guarded.withLock { states[number] = nil }
            return nil
        }

        return storage
    }

    /// Puts the numbering back to a fresh process's, for the tests, whose fixtures
    /// compare bytes. Never while an interface runs.
    func clearStates() {
        let issued = guarded.withLock { () -> [() -> HostStorage?] in
            let held = Array(states.values)
            states.removeAll()
            return held
        }

        for storage in issued {
            storage()?.number = nil
        }

        nextNumber = 1

        for board in boards {
            board.clear()
        }
    }


    /// What the next render will act on - for tests driving a differ of their own.
    var pendingChanges: Set<ObjectIdentifier> { guarded.withLock { changed } }

    /// What those changes are called, for the same tests.
    var pendingNames: [ObjectIdentifier: String] { guarded.withLock { names } }

    /// Whether a render was asked for without naming a state - for tests.
    var hasUntrackedCause: Bool { guarded.withLock { untracked } }

    /// Puts the bookkeeping back to "nothing has changed", for a test's start.
    func clearInvalidation() {
        guarded.withLock {
            dirty = false
            changed.removeAll()
            names.removeAll()
            untracked = false
        }
    }

    /// Whether anything has changed since the last render. The host polls this
    /// rather than being called back, so nothing here calls into the host.
    public var needsRender: Bool { guarded.withLock { dirty } }

    /// Renders and serializes the patch against `baseline`, the generation the
    /// caller holds; any other baseline gets the whole tree.
    /// Design: docs/design/core/render.md#generations-and-baseline
    func renderWire(baseline: Int32) -> [UInt8] {
        render(baseline: baseline) { rendered in
            let wire = Wire.encode(
                rendered.root,
                generation: rendered.generation,
                complete: rendered.complete,
                dictionary: wireDictionary)

            return (wire, wire.count)
        }
    }

    /// Renders the same patch typed, for a Swift host.
    func renderHost(baseline: Int32) -> HostRender {
        render(baseline: baseline) { rendered in
            (HostRender(
                generation: rendered.generation,
                complete: rendered.complete,
                root: rendered.root), 0)
        }
    }

    /// One render, delivered as the caller carries it; delivery is timed as encoding.
    private func render<Output>(
        baseline: Int32,
        deliver: ((generation: Int32, complete: Bool, root: HostPatch)) -> (Output, Int)
    ) -> Output {
        // The first render is complete although both sides agree at zero.
        let describeAll = baseline != generation || rendered == nil

        // Taken and cleared in one locked step, so a write landing during this render
        // asks for the next one.
        // Design: docs/design/core/render.md#taking-the-changes
        let (changedNow, untrackedNow, namesNow):
            (Set<ObjectIdentifier>, Bool, [ObjectIdentifier: String]) = guarded.withLock {
            let taken = (changed, untracked, names)
            changed.removeAll()
            names.removeAll()
            untracked = false
            dirty = false
            rendering = true
            return taken
        }

        // Taken once: naming a build must never reach a lock.
        differ.named = namesNow

        let walks = rendered != nil && !describeAll && !untrackedNow
            && rootReads.isDisjoint(with: changedNow)

        // What an inspector is told: the road, the causes and the timings.
        let inspecting = Inspection.recording
        let began: ContinuousClock.Instant? = inspecting ? .now : nil

        if inspecting {
            var causes = Set(changedNow.map { namesNow[$0] ?? "state" }).sorted()

            if untrackedNow {
                causes.append("a render asked for without naming a state")
            }

            Inspection.begin(road: describeAll ? .complete : (walks ? .walk : .build), causes: causes)
        }

        let result: (node: RenderedNode, patch: HostPatch)

        if let current = rendered, walks {
            // The clean walk: every cause named its state and none was a root read.
            // Design: docs/design/core/render.md#three-roads
            result = differ.revisit(current, changed: changedNow)
        } else {
            let (built, reads) = ReadScope.collect { root }

            // The root build is a reader too.
            unreading(rootReads)
            reading(reads)
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

        // Zero is the host's "start over"; a wrapped counter skips it.
        if generation == 0 { generation = 1 }

        renders += 1

        // A streak of renders left dirty is a body writing what it reads: reported, and
        // the pending change dropped once.
        // Design: docs/design/core/render.md#self-dirtying-renders
        let dirtiedMeanwhile: Bool = guarded.withLock {
            rendering = false
            return dirty
        }

        if dirtiedMeanwhile {
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

        // The handlers the walk found run now, and what they write is merged into this
        // message, up to `settleLimit` passes.
        // Design: docs/design/core/render.md#handlers-in-the-message
        var patch = result.patch

        for _ in 0..<Renderer.settleLimit {
            let handlers = differ.takeFired()

            if handlers.isEmpty {
                break
            }

            for handler in handlers {
                run(handler)
            }

            let (wrote, wroteUntracked, wroteNames):
                (Set<ObjectIdentifier>, Bool, [ObjectIdentifier: String]) = guarded.withLock {
                let taken = (changed, untracked, names)
                changed.removeAll()
                names.removeAll()
                untracked = false
                dirty = false
                rendering = true
                return taken
            }

            // Nothing they wrote is read anywhere.
            if wrote.isEmpty && !wroteUntracked {
                guarded.withLock { rendering = false }
                break
            }

            differ.named = wroteNames

            let settled: (node: RenderedNode, patch: HostPatch)

            if let current = rendered, !wroteUntracked, rootReads.isDisjoint(with: wrote) {
                settled = differ.revisit(current, changed: wrote)
            } else {
                let (built, reads) = ReadScope.collect { root }

                unreading(rootReads)
                reading(reads)
                rootReads = reads
                differ.motion = built.motion

                settled = differ.reconcile(
                    rendered, with: built.tree, styles: built.styles, changed: wrote)
            }

            guarded.withLock { rendering = false }

            rendered = settled.node
            patch = patch.merging(settled.patch)
        }

        let described = began.map { Inspection.micros(since: $0) } ?? 0

        if patch.isEmpty {
            emptyRenders += 1
        }

        let encoding: ContinuousClock.Instant? = inspecting ? .now : nil

        let (output, bytes) = deliver((generation, describeAll, patch))

        // A render the inspector's own state alone caused is not kept, whichever road
        // it took.
        // Design: docs/design/core/diagnostics.md#the-inspector
        if let encoding {
            let own = !changedNow.isEmpty && !untrackedNow
                && changedNow.isSubset(of: Inspection.ownStates)

            Inspection.end(
                generation: generation,
                describe: described,
                encode: Inspection.micros(since: encoding),
                bytes: bytes,
                keep: !own)
        }

        // Handlers found with no pass left are queued, not started: started now, their
        // writes would land after the host's look for work.
        // Design: docs/design/core/render.md#handlers-in-the-message
        for handler in differ.takeFired() {
            queue(handler)
        }

        return output
    }

    /// The whole tree, its styles and its motion, read in one scope, so whatever
    /// they read lands in `rootReads`.
    private var root: (tree: Node, styles: StyleSheet?, motion: Motion) {
        guard let application = application else {
            return (Renderer.unregistered, nil, .standard)
        }

        // The application is the root and its open scenes its children.
        let session = StandardEnvironment.application

        return (Scenes.shared.tree(of: application), session.styles, session.motion)
    }

    /// Shown until an application registers, in the shape a real one has.
    private static var unregistered: Node {
        var label = Node(contract: LabelContract.self)
        label.write(TextElementContract.text, "StateUI: no application registered")

        let page = Node(contract: PageContract.self, children: [label])
        let main = Node(contract: WindowContract.self, id: SceneElement.mainKey, children: [page])
        let scene = Node(contract: SceneContract.self, id: "1", children: [main])

        return Node(contract: ApplicationContract.self, children: [scene])
    }

    /// Registers a waiter for an animation's end and answers the id written on its
    /// image - the counter every awaited act draws from.
    /// Design: docs/design/core/journeys.md#moving-and-waiting
    func book(_ completion: @escaping (Reply) -> Void) -> Int {
        guarded.withLock { () -> Int in
            let issued = nextCompletionId

            completions[issued] = completion
            nextCompletionId -= 1

            return issued
        }
    }

    /// The completions nobody has answered yet - what a test playing the host answers.
    var waiting: [Int] { guarded.withLock { Array(completions.keys) } }

    /// Queues an act by its token, the library's or an application's.
    func send(_ act: Act, _ arguments: [PropValue], completion: ((Reply) -> Void)?) {
        enqueue({ ActCall(act: act, arguments: arguments, completion: $0) }, completion)
    }

    /// Queues a library act nobody waits on, its arguments as its member declares.
    func send<Owner: Contract, each Argument: HostRepresentable, Answer>(
        _ act: ElementAct<Owner, (repeat each Argument), Answer>,
        _ arguments: repeat each Argument
    ) {
        send(act.token, MemberValues.encode(repeat each arguments), completion: nil)
    }

    /// Queues an act. Callable from any thread: `async let` children send from the pool.
    private func enqueue(_ make: (Int?) -> ActCall, _ completion: ((Reply) -> Void)?) {
        guarded.withLock {
            var id: Int?

            if let completion = completion {
                id = nextCompletionId
                completions[nextCompletionId] = completion
                nextCompletionId -= 1
            }

            actCalls.append(make(id))
        }

        // Wakes the host outside the lock: an act sent from a plain `Task` lands no job
        // on the executor, and nothing else would tell the host it is there.
        UIThreadExecutor.shared.poke()
    }

    /// Acts queued and not yet taken, waiting saves included - work to the doorbell.
    var actCallsPending: Int {
        // A save waiting is an act the moment it is taken (Core/Persistence.swift).
        guarded.withLock { actCalls.count } + PersistentStore.shared.pending
            + Scenes.shared.pendingSaves
    }

    /// Queues an act and suspends until the host answers, running and resuming on
    /// the caller's executor. Throws `StateUIError` with the host's reason.
    /// Design: docs/design/core/acts.md#awaiting-an-answer
    nonisolated(nonsending) func call(
        _ act: Act,
        _ arguments: [PropValue] = []
    ) async throws -> [PropValue] {
        try await answered { self.send(act, arguments, completion: $0) }
    }

    /// The suspension itself: queues through `send`, waits for the reply, and
    /// turns its two arms into a return and a throw.
    nonisolated(nonsending) func answered(
        _ send: (@escaping (Reply) -> Void) -> Void
    ) async throws -> [PropValue] {
        let reply = await withCheckedContinuation { (continuation: CheckedContinuation<Reply, Never>) in
            send { outcome in
                // Counted here and lowered first thing after the resume, so a host can tell a
                // resume still landing from nothing to wait for.
                Renderer.shared.guarded.withLock { Renderer.shared.resumes += 1 }
                continuation.resume(returning: outcome)
            }
        }

        // On a pool thread when the caller was a child task, hence the lock.
        guarded.withLock { resumes -= 1 }

        switch reply {
        case .finished(let values):
            return values
        case .failed(let message):
            throw StateUIError(message: message)
        }
    }

    /// Reports a handler that threw, as an ordinary act.
    func report(_ error: Error) {
        send(ApplicationContract.handlerFailed, String(describing: error))
    }

    /// Hands the queued acts to the host as bytes, keeping the batch's completion
    /// ids as a receipt. An empty queue answers no bytes.
    /// Design: docs/design/core/acts.md#the-receipt
    func takeActCallsWire() -> [UInt8] {
        let batch = takeActCalls()
        return batch.isEmpty ? [] : Wire.encode(batch, dictionary: wireDictionary)
    }

    /// Hands the queued acts over typed; a Swift host answers each by its id.
    func takeActCalls() -> [ActCall] {
        // Saves become acts here, one per key per take with the last value.
        // Design: docs/design/core/state.md#kept-state
        let saves = PersistentStore.shared.takeWaiting().map {
            ActCall(ApplicationContract.persistValue, Name($0.name), $0.value)
        }

        let queued = guarded.withLock {
            let queued = actCalls
            actCalls.removeAll(keepingCapacity: true)
            takenCompletions = queued.compactMap { $0.completion }
            return queued
        }

        // And what the open scenes keep, the same way (Core/Scenes.swift).
        return queued + saves + Scenes.shared.takeSaves()
    }

    /// The store the application keeps state in and its keys, for the host to read
    /// before the first render; empty for an application that keeps nothing.
    func persistentWire() -> [UInt8] {
        let session = StandardEnvironment.application

        guard application != nil, !session.persistentKeys.isEmpty else { return [] }

        return Wire.encodePersistent(
            storage: session.persistentStorage,
            keys: session.persistentKeys)
    }

    /// Fails every act of the last taken batch, which the host could not read: each
    /// awaiting handler throws instead of waiting for ever.
    /// Design: docs/design/core/acts.md#the-receipt
    func failTakenActCalls(_ reason: String) {
        let ids = guarded.withLock {
            let ids = takenCompletions
            takenCompletions = []
            return ids
        }

        for id in ids {
            // The two steps the export takes for a reply from the host.
            ReplyBuffer.current = .failed(reason)
            _ = dispatch(id)
        }
    }

    /// Runs what an id refers to: an element's handler, or a waiting continuation
    /// when negative. False for an unknown id, which is not an error.
    /// Design: docs/design/core/render.md#starting-a-handler
    func dispatch(_ handlerId: Int) -> Bool {
        if handlerId < 0 {
            // Removed under the lock, invoked outside it: a resume may run code that takes it.
            let taken = guarded.withLock { completions.removeValue(forKey: handlerId) }

            guard let completion = taken else { return false }
            completion(ReplyBuffer.current)

            // Nothing runs here: the job a resume produces does not exist yet.
            return true
        }

        // The differ holds these: a carried element still answers for its buttons.
        guard let handler = differ.handler(handlerId) else { return false }

        start(handler)
        return true
    }

    /// Starts a dispatched event's handler - the road a test exercises too.
    func start(_ handler: @escaping EventHandler) {
        // Read now: a handler that suspends keeps the payload it started with.
        begin(handler, payload: EventBuffer.current)
    }

    /// Runs a handler a render's walk found, with no payload.
    func run(_ handler: @escaping EventHandler) {
        begin(handler, payload: nil)
    }

    /// Runs a handler on `MainActor` here and now, up to its first suspension.
    /// Design: docs/design/core/render.md#starting-a-handler
    private func begin(_ handler: @escaping EventHandler, payload: [PropValue]?) {
        let carried = CarriedHandler(run: handler)

        Task.immediate { @MainActor in
            if let payload {
                EventBuffer.current = payload
            }

            do {
                try await carried.run()
            } catch {
                Renderer.shared.report(error)
            }
        }

        stateUIRunJobs()
    }

    /// Starts a handler on `MainActor` in a later turn - for what a render found
    /// with no settle pass left.
    func queue(_ handler: @escaping EventHandler) {
        let carried = CarriedHandler(run: handler)

        Task { @MainActor in
            do {
                try await carried.run()
            } catch {
                Renderer.shared.report(error)
            }
        }
    }
}

/// Carries a handler into its `MainActor` task, the one place its sendability
/// is promised.
/// Design: docs/design/core/render.md#the-event-and-reply-buffers
private struct CarriedHandler: @unchecked Sendable {
    let run: EventHandler
}

/// The payload of the event being dispatched, in the event's declared order.
/// Design: docs/design/core/render.md#the-event-and-reply-buffers
enum EventBuffer {
    // Written and read during one dispatch, on the UI thread.
    nonisolated(unsafe) static var current: [PropValue] = []
}

/// The outcome of the act being answered, read by the continuation it resumes.
enum ReplyBuffer {
    // Written and read during one dispatch, on the UI thread.
    nonisolated(unsafe) static var current: Reply = .finished([])
}
