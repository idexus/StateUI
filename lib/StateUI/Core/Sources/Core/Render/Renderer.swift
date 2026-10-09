// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The renderer: it holds the application, knows what changed since the last
// render, and renders the typed patch a host applies.
// Design: docs/design/core/render.md#one-renderer

/// The one renderer: it holds the application and renders what changed for
/// the host, which calls in from the thread it draws on.
@MainActor
public final class Renderer {
    // The UI thread's actor's: the host enters it from that thread, synchronously.
    // Design: docs/design/core/render.md#one-renderer

    /// The one renderer: a process has one host.
    public static let shared = Renderer()

    private var application: (any Application)?

    /// The registered application, still to be made: it is made at its first need - the first render, or the
    /// host reading the keys it keeps - so after the host has told what the device is.
    private var making: (() -> any Application)?
    private var dirty = true

    /// The states written since the last render, by storage identity, each held
    /// until the render takes it - named only when `debugInfo()` or an inspector
    /// asks (`BuildScope.name(of:)`).
    private var written: [ObjectIdentifier: AnyObject] = [:]

    /// Whether a render was asked for without naming a state, which makes the next
    /// render build the whole tree.
    private var untracked = true

    /// What the last root build read outside every element; a change to any of it
    /// builds the application again.
    /// Design: docs/design/core/render.md#three-roads
    private var rootReads: Set<ObjectIdentifier> = []

    /// How many live elements read each state, by storage identity. A write to a
    /// state nobody reads asks for nothing.
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
        liveNodes += 1
    }

    func nodeGone() {
        liveNodes -= 1
    }

    let differ = Differ()

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

    /// Acts waiting for the host to take them (ActCall.swift).
    var actCalls: [ActCall] = []

    /// Continuations waiting for an act or an animation to finish, by negative id.
    /// Design: docs/design/core/acts.md#completion-ids
    var completions: [Int: (Reply) -> Void] = [:]
    var nextCompletionId = -1

    /// How many handlers were told their act is over and have not run a line since;
    /// a test waits on it for a queue gone quiet.
    /// Design: docs/design/core/acts.md#awaiting-an-answer
    var resumesPending = 0

    /// One board per sync; the display's frame is the only sync.
    /// Design: docs/design/core/cycle.md#the-board
    let boards: [CycleBoard] = [CycleBoard(sync: .display)]

    /// Every state issued a number, held weakly: a storage belongs to its view.
    var states: [Int32: () -> HostStorage?] = [:]

    /// The next state number, from one.
    var nextNumber: Int32 = 1

    private init() {}

    /// Registers the application. Called through `stateUIUseApp`.
    ///
    /// - Parameter application: the application, made at its first need, once
    ///   what an earlier registration wrote into the application's session is
    ///   forgotten and the host has told what the device is.
    @_spi(Host) public func setApplication(_ application: @escaping @autoclosure () -> any Application) {
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

        self.application = nil
        making = application

        // The scene launch opens, its window waiting for the platform's first (OpenScenes.swift).
        OpenScenes.shared.reset()

        setNeedsRender()
    }

    /// The registered application, made the first time it is needed.
    /// Design: docs/design/core/render.md#a-new-application
    @discardableResult
    func madeApplication() -> (any Application)? {
        if application == nil, let making {
            self.making = nil
            let made = making()
            application = made
            Renderer.name(statesOf: made)
            OpenScenes.shared.settleLaunch(Scenes.of(made.body))
        }
        return application
    }

    /// Names the application's own `@State` by their properties, once, since the
    /// application is never walked like a view.
    static func name(statesOf application: any Application) {
        for child in Mirror(reflecting: application).children {
            if let label = child.label, let box = child.value as? StateBox {
                box.named(label)
            }
        }
    }

    /// Asks for a render without naming what changed, so the next render builds
    /// the whole tree. It asks the host for a turn.
    public func setNeedsRender() {
        dirty = true
        untracked = true
        UIThreadExecutor.shared.askForTurn()
    }

    /// Records that a state was read. While a view is built, the view becomes
    /// its reader; anywhere else it costs nearly nothing.
    ///
    /// - Returns: whether a build was open to record it.
    @discardableResult
    @usableFromInline func stateRead(_ state: AnyObject) -> Bool {
        #if DEBUG
        HandlerRun.noteRead(of: state)
        #endif
        return ReadScope.note(ObjectIdentifier(state))
    }

    /// Records that a state was written and asks for a render that rebuilds only
    /// the views that read it. A state no live element reads asks for nothing.
    /// It asks the host for a turn.
    func stateChanged(_ state: AnyObject) {
        let id = ObjectIdentifier(state)

        guard rendering || readers[id] != nil else {
            refusedWrites += 1
            return
        }

        dirty = true
        written[id] = state
        UIThreadExecutor.shared.askForTurn()
    }

    /// Counts one more live reader of each state - an element as it is made, or
    /// the root build.
    func reading(_ states: Set<ObjectIdentifier>) {
        for id in states {
            readers[id, default: 0] += 1
        }
    }

    /// Counts one reader fewer of each state - the element that read them has gone.
    func unreading(_ states: Set<ObjectIdentifier>) {
        for id in states {
            guard let count = readers[id] else { continue }

            readers[id] = count > 1 ? count - 1 : nil
        }
    }

    /// Whether any live element reads this state - what a test asks.
    func isRead(_ state: AnyObject) -> Bool {
        readers[ObjectIdentifier(state)] != nil
    }

    /// What the next render will act on - for tests driving a differ of their own.
    var pendingChanges: Set<ObjectIdentifier> { Set(pendingWrites.keys) }

    /// The states those changes are, for the same tests to name.
    var pendingWrites: [ObjectIdentifier: AnyObject] { written }

    /// Whether a render was asked for without naming a state - for tests.
    var hasUntrackedCause: Bool { untracked }

    /// Puts the bookkeeping back to "nothing has changed", for a test's start.
    func clearInvalidation() {
        dirty = false
        written.removeAll()
        untracked = false
    }

    /// Whether anything has changed since the last render. The host polls this
    /// rather than being called back, so nothing here calls into the host.
    var needsRender: Bool { dirty }

    /// Takes what was written since the last take and starts a render, in one step,
    /// so a write landing during this render asks for the next one.
    /// Design: docs/design/core/render.md#taking-the-changes
    private func takeWritten() -> (written: [ObjectIdentifier: AnyObject], untracked: Bool) {
        defer {
            written.removeAll()
            untracked = false
            dirty = false
            rendering = true
        }

        return (written, untracked)
    }

    /// Renders the patch against `baseline`, the generation the host holds;
    /// any other baseline gets the whole tree.
    /// Design: docs/design/core/render.md#generations-and-baseline
    func renderHost(baseline: Int32) -> HostRender {
        // The first render is complete although both sides agree at zero.
        let describeAll = baseline != generation || rendered == nil

        let (writtenNow, untrackedNow) = takeWritten()

        let changedNow = Set(writtenNow.keys)

        // Taken once, and held for this render alone: naming a build reads it.
        differ.written = writtenNow
        defer { differ.written = [:] }

        let walks = rendered != nil && !describeAll && !untrackedNow
            && rootReads.isDisjoint(with: changedNow)

        // What an inspector is told: the road, the causes and the timings.
        let inspecting = Inspection.recording
        let began: ContinuousClock.Instant? = inspecting ? .now : nil

        if inspecting {
            var causes = Set(writtenNow.values.map { BuildScope.name(of: $0) }).sorted()

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
        rendering = false
        let dirtiedMeanwhile = dirty

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

            let (wroteNow, wroteUntracked) = takeWritten()

            let wrote = Set(wroteNow.keys)

            // Nothing they wrote is read anywhere.
            if wrote.isEmpty && !wroteUntracked {
                rendering = false
                break
            }

            differ.written = wroteNow

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

            rendering = false

            rendered = settled.node
            patch = patch.merging(settled.patch)
        }

        let described = began.map { Inspection.micros(since: $0) } ?? 0

        if patch.isEmpty {
            emptyRenders += 1
        }

        let message = HostRender(generation: generation, complete: describeAll, root: patch)

        // A render the inspector's own state alone caused is not kept, whichever road
        // it took.
        // Design: docs/design/core/diagnostics.md#the-inspector
        if inspecting {
            let own = !changedNow.isEmpty && !untrackedNow
                && changedNow.isSubset(of: Inspection.ownStates)

            Inspection.end(generation: generation, describe: described, keep: !own)
        }

        // Handlers found with no pass left are queued, not started: started now, their
        // writes would land after the host's look for work.
        // Design: docs/design/core/render.md#handlers-in-the-message
        for handler in differ.takeFired() {
            queue(handler)
        }

        return message
    }

    /// The whole tree, its styles and its motion, read in one scope, so whatever
    /// they read lands in `rootReads`.
    private var root: (tree: Node, styles: StyleSheet?, motion: Motion) {
        guard let application = madeApplication() else {
            return (Renderer.unregistered, nil, .standard)
        }

        // The application is the root and its open scenes its children.
        let session = StandardEnvironment.application

        return (OpenScenes.shared.tree(of: application), session.styles, session.motion)
    }

    /// Shown until an application registers, in the shape a real one has.
    private static var unregistered: Node {
        var label = Node(contract: TextContract.self)
        label.write(TextualElementContract.text, "StateUI: no application registered")

        let page = Node(contract: PageContract.self, children: [label])
        let window = Node(contract: WindowContract.self, id: "window 1", children: [page])
        let scene = Node(contract: SceneContract.self, id: "1", children: [window])

        return Node(contract: ApplicationContract.self, children: [scene])
    }
}
