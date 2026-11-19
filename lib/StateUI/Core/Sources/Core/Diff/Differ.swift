// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The differ: what a render built, walked against the tree the host holds, with
// only the differences packed into a `HostPatch`. Element ids and handler ids
// are allocated here, because both outlive the tree that made them.
// Design: docs/design/core/identity-and-diffing.md#keys

/// Walks the authored tree against the rendered one and produces the message.
/// Design: docs/design/core/identity-and-diffing.md#what-a-walk-keeps
@MainActor
final class Differ {
    /// The next element id. Never reset, not even by a resync.
    /// Design: docs/design/core/identity-and-diffing.md#ids-are-never-reused
    private var nextElementId = 1

    let menuKeys = MenuKeys()

    /// The next handler id, under the same rule.
    private var nextHandlerId = 1

    /// Which walk this is, so an aim knows one walk from the next.
    private(set) var walkStamp = 0

    /// Whether this walk describes every element in full, for a resync.
    /// Design: docs/design/core/identity-and-diffing.md#a-resync-keeps-matching
    private(set) var describeAll = false

    /// The style sheet this walk resolves every element against.
    private(set) var styles: StyleSheet?

    /// How a changed value animates where its element says nothing else.
    var motion: Motion = .standard

    /// Whether the sheet moved at the top of this walk, which carries no view.
    /// Design: docs/design/core/identity-and-diffing.md#what-a-carry-cannot-see
    private(set) var stylesMoved = false

    /// Whether this walk builds every composed view: `setNeedsRender()` named nothing StateUI tracks.
    /// Design: docs/design/core/identity-and-diffing.md#what-a-carry-cannot-see
    private(set) var buildsEveryView = false

    /// The states written since the tree the host holds was built.
    private(set) var changed: Set<ObjectIdentifier> = []

    /// The changed states themselves, for `debugInfo()` and an inspector to name
    /// (Builds.swift).
    var written: [ObjectIdentifier: AnyObject] = [:]

    /// Whether the element described next is the view a page shows, whose page values the page takes.
    var describesPageRoot = false

    /// The element standing the element described next where a page stands - a window, an arrangement, a sheet -
    /// through any anchor between them; nil where no page stands.
    var describesPagePlacer: NodeType?

    /// The handlers this walk found to run - `.onChanged`, `.onCreated` and
    /// `.onVisualStateChanged` - in the order reached.
    /// Design: docs/design/core/render.md#handlers-in-the-message
    var fired: [Fired] = []

    /// The `.onDestroying` handlers of what this walk let go, innermost first.
    private var leaving: [EventHandler] = []

    /// The states whose consumers this walk changed, for their channels to be settled once it is done.
    /// Design: docs/design/core/journeys.md#a-channels-life
    private var touched: [HostStorage] = []

    /// The environments in scope where the walk stands, nearest last.
    var scope: [(key: ObjectIdentifier, object: AnyObject)] = []

    /// The composed views whose bodies the walk is inside, outermost first.
    var bodies: [String] = []

    /// The elements the walk is inside, outermost first (Differ+Element.swift).
    var standing: [ElementID] = []

    /// Where each `@Environment` slot met this walk last stood, built or kept, and what it resolved to there.
    /// Design: docs/design/core/identity-and-diffing.md#one-value-in-two-places
    var placed: [ObjectIdentifier: (place: [ElementID], object: ObjectIdentifier?)] = [:]

    /// What each element holding the one walked says of its enablement, outermost first - those that say any.
    /// Design: docs/design/views/styles.md#which-state-a-control-is-in
    var enablements: [Enablement] = []

    /// What every live element's events run, and their runs, kept between renders.
    /// Design: docs/design/core/identity-and-diffing.md#handlers-and-their-ids
    var handlers: [Int: EventRegistration] = [:]

    /// The two phases of each page listening for its disappearing, by their handler ids: the page, and whether the
    /// phase is its appearing.
    private var pagePhases: [Int: (page: ElementID, appears: Bool)] = [:]

    /// The pages the host told they appeared and not yet that they disappeared.
    private var shownPages: Set<ElementID> = []

    /// The scene the walk is inside; `OpenScenes.building` follows it.
    var sceneRecord: SceneRecord? {
        didSet { OpenScenes.shared.building = sceneRecord }
    }

    /// Reconciles the tree just built against the one the host holds. `describeAll`
    /// makes the patch complete while matching stays as it always is; a nil
    /// `rendered` is only for a first render.
    func reconcile(
        _ rendered: RenderedNode?,
        with tree: Node,
        styles: StyleSheet? = nil,
        describeAll: Bool = false,
        changed: Set<ObjectIdentifier> = [],
        buildsEveryView: Bool = false
    ) -> (node: RenderedNode, patch: HostPatch) {
        menuKeys.prune()
        self.describeAll = describeAll
        self.buildsEveryView = buildsEveryView
        self.changed = changed
        stylesMoved = !StyleSheet.same(styles, self.styles)
        self.styles = styles
        walkStamp += 1
        seedScope()

        let previous = rendered?.identity == tree.identity ? rendered : nil
        let id = previous?.id ?? identity(for: tree)

        if let rendered = rendered, previous == nil {
            forget(rendered)
        }

        let walked = element(id: id, rendered: previous, node: tree)
        settleChannels()
        return walked
    }

    /// The clean walk: no fresh tree, and exactly the elements whose reads intersect
    /// `changed` are built again. Sound only when every cause named its state.
    /// Design: docs/design/core/identity-and-diffing.md#the-clean-walk
    func revisit(
        _ rendered: RenderedNode,
        changed: Set<ObjectIdentifier>
    ) -> (node: RenderedNode, patch: HostPatch) {
        menuKeys.prune()
        describeAll = false
        buildsEveryView = false
        self.changed = changed
        stylesMoved = false
        walkStamp += 1
        seedScope()

        let walked = revisit(rendered)
        settleChannels()
        return walked
    }

    /// A state this element shows: a consumer more, settled once the walk is done.
    func tie(_ state: HostStorage) {
        state.consumers += 1
        touched.append(state)
    }

    /// A state this element no longer shows: a consumer fewer, and its answer for `.inherited` gone with it.
    func untie(_ number: Int32, from id: ElementID) {
        guard let state = Renderer.shared.storage(of: number) else { return }

        state.consumers -= 1
        touched.append(state)
    }

    /// Settles the channels of the states whose consumers the walk changed, once it is done - never while one
    /// element lets a state go and another takes it in the same walk. A first consumer opens a channel of a new
    /// generation; the last one gone closes it: the value stands at its destination, still, its sample goes, and
    /// whoever waits on a movement of it hears `.detached` - the host's channel went with the consumer and
    /// answers nobody.
    /// Design: docs/design/core/journeys.md#a-channels-life
    private func settleChannels() {
        let changed = touched
        touched = []
        let board = Renderer.shared.board
        var settled = Set<ObjectIdentifier>()

        for state in changed where settled.insert(ObjectIdentifier(state)).inserted {
            guard state.settleChannel(), state.door == .property,
                  case .lanes(var lanes) = board.read(state, lanes: StateValueLanes.own),
                  let law = StateLaw.within(.property, lanes: lanes.count)
            else { continue }

            let (width, completion) = (law / 3, lanes[law + StateLaw.lanes])
            for lane in 0..<width {
                lanes[lane] = lanes[width + lane]
                lanes[width * 2 + lane] = 0
            }
            lanes[law + StateLaw.lanes] = 0
            board.write(StateImage.bytes(of: .lanes(lanes)), to: state, stamping: false)
            if let id = Int(exactly: completion), id != 0 { HostBoundary.complete(id, as: .detached) }
        }
    }

    /// One kept element: built again from its placeholder when its reads moved - from the outermost of its views
    /// whose own body read what moved, those outside it standing as they were - or when it stands refused, to ask
    /// again; else its views stand, their slots placed as they were, from the first one refused this walk built
    /// again, which refuses it; walked for changed descendants.
    /// Design: docs/design/core/identity-and-diffing.md#the-clean-walk
    func revisit(
        _ rendered: RenderedNode,
        walking: Bool = true,
        standingAlready: Bool = false
    ) -> (node: RenderedNode, patch: HostPatch) {
        if let placeholder = rendered.placeholder {
            let moved = !rendered.reads.isDisjoint(with: changed)
            let from = moved
                ? Self.start(of: rendered, changed: changed)
                : rendered.refused ? 0 : stand(rendered.views[...], at: standing + [rendered.id])

            if moved || rendered.refused || from < rendered.views.count {
                return element(
                    id: rendered.id,
                    rendered: rendered,
                    node: placeholder,
                    forced: true,
                    sizesArrive: rendered.sizesArrive,
                    pagePlacer: rendered.pagePlacer,
                    from: from)
            }
        }

        // Its key on the walk's stack while it stands here, unless the caller pushed it (the carried road).
        if !standingAlready { standing.append(rendered.id) }
        defer { if !standingAlready { standing.removeLast() } }

        // An element left standing attaches its aims in this walk as a built one does: the one its parent wrote on
        // it, and the one on its content's root (Aim.swift).
        rendered.placeholder?.aim?.attach(standing, walk: walkStamp)
        rendered.contentAim?.attach(standing, walk: walkStamp)

        // A composed view walked past is written down only as the path to something
        // built below it, and not for a view just carried.
        let walked = walking && Inspection.recording && !rendered.views.isEmpty
            && Inspection.enter(rendered.views[0].type.name, .walked, element: rendered.id)
        defer { if walked { Inspection.leave() } }

        // And the scene it is in, whose record the kept state below is claimed from.
        let outer = sceneRecord
        if rendered.type == .scene, sceneRecord == nil, case .manual(let name) = rendered.id {
            sceneRecord = OpenScenes.shared.record(key: name)
        }
        defer { sceneRecord = outer }

        var patch = HostPatch(id: rendered.id, type: rendered.type)

        // What this element provided stays in scope while its children are walked, and what it says of its
        // enablement holds for them.
        scope.append(contentsOf: rendered.provided)
        defer { scope.removeLast(rendered.provided.count) }
        if let enablement = rendered.enablement { enablements.append(enablement) }
        defer { if rendered.enablement != nil { enablements.removeLast() } }

        var changedChildren: [HostPatch] = []

        for (index, child) in rendered.children.enumerated() {
            let (node, childPatch) = revisit(child)
            rendered.children[index] = node

            if !childPatch.isEmpty {
                changedChildren.append(childPatch)
            }
        }

        if !changedChildren.isEmpty {
            patch.children = .changed(changedChildren)
        }

        return (rendered, patch)
    }

    /// What an element's event runs, or nothing if the id is unknown.
    func handler(_ id: Int) -> EventRegistration? {
        handlers[id]
    }

    /// The host told the event under `handlerId`: a page appearing stands shown, one disappearing no longer.
    /// Design: docs/design/host/pages.md#a-page-that-leaves-the-tree
    func heard(_ handlerId: Int) {
        guard let phase = pagePhases[handlerId] else { return }
        if phase.appears { shownPages.insert(phase.page) } else { shownPages.remove(phase.page) }
    }

    /// Keeps the two phases of page `id` that tell whether it stands shown, under the ids its `events` hold them by.
    func keepPhases(of id: ElementID, _ events: [Event: Int]) {
        guard let appearing = events[.appearing], let disappearing = events[.disappearing] else { return }
        pagePhases[appearing] = (id, true)
        pagePhases[disappearing] = (id, false)
    }

    /// The handlers the last walk found - what left first, then the rest - taken so
    /// each runs once.
    func takeFired() -> [Fired] {
        let taken = leaving.map { Fired(run: $0, owner: nil) } + fired
        leaving.removeAll(keepingCapacity: true)
        fired.removeAll(keepingCapacity: true)
        return taken
    }

    /// Drops the handlers and engines of an element that left the tree, and of
    /// everything under it, and books its `.onDestroying` - a page standing
    /// shown its `.onDisappearing` first.
    func forget(_ node: RenderedNode) {
        if shownPages.remove(node.id) != nil, let id = node.events[.disappearing], let registration = handlers[id] {
            // Heard as a host tells a phase: carrying nothing, whatever the event that left it carried.
            leaving.append(contentsOf: registration.handlers.map { handler in
                let run = handler.run
                return { @MainActor in
                    EventBuffer.current = []
                    try await run()
                }
            })
        }
        for id in node.events.values { pagePhases[id] = nil }

        for (_, id) in node.events.sorted(by: { $0.key < $1.key }) {
            handlers.removeValue(forKey: id)?.orphan()
        }
        node.runs.orphan()

        // Its engines: nothing is left to ask for their frames.
        for id in node.engines {
            Renderer.shared.disarm(id)
        }

        // Its ties: the states it showed, and those whose journey it followed, have a consumer fewer.
        for entry in node.driven.values {
            untie(entry.number, from: node.id)
        }
        for entry in node.followed {
            untie(entry.number, from: node.id)
        }

        // Its conversions: the graph works them out for one wearer fewer.
        node.conversions.forEach(Renderer.shared.board.conversions.unwear)

        for child in node.children {
            forget(child)
        }

        // Its `.onDestroying`, once its subtree's is booked - innermost first.
        leaving.append(contentsOf: node.destroying)
    }

    /// Starts a walk's scope with the standard providers, so any view resolves them and an app's own
    /// `.environment()` below is nearer (StandardEnvironment.swift); forgets where the last walk placed its slots.
    private func seedScope() {
        scope.removeAll(keepingCapacity: true)
        scope.append(contentsOf: StandardEnvironment.scope)
        placed.removeAll(keepingCapacity: true)
    }

    // MARK: - Identity

    /// A literal string keeps its name; every other element gets a fresh number.
    func identity(for node: Node) -> ElementID {
        if let name = node.identity?.value.base as? String { return .manual(name) }
        return .auto(allocateElementId())
    }

    /// The next element id. Never reused.
    func allocateElementId() -> Int {
        let id = nextElementId
        nextElementId += 1
        return id
    }

    /// The next handler id. Never reused.
    func allocateHandlerId() -> Int {
        let id = nextHandlerId
        nextHandlerId += 1
        return id
    }
}
