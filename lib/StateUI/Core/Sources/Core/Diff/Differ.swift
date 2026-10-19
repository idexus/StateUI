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

    /// The handlers this walk found to run - `.onChanged`, `.onCreated` and
    /// `.onVisualStateChanged` - in the order reached.
    /// Design: docs/design/core/render.md#handlers-in-the-message
    var fired: [Fired] = []

    /// The driven values this walk heard an element answer `.inherited` for, with the property, to check once the
    /// walk let go of what left.
    var answered: [(state: HostStorage, key: Prop)] = []

    /// The `.onDestroying` handlers of what this walk let go, innermost first.
    private var leaving: [EventHandler] = []

    /// The environments in scope where the walk stands, nearest last.
    var scope: [(key: ObjectIdentifier, object: AnyObject)] = []

    /// The composed views whose bodies the walk is inside, outermost first.
    var bodies: [String] = []

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
        self.describeAll = describeAll
        self.buildsEveryView = buildsEveryView
        self.changed = changed
        stylesMoved = !StyleSheet.same(styles, self.styles)
        self.styles = styles
        walkStamp += 1
        seedScope()

        // The root keeps whatever key it was given until the author states another.
        let id = tree.id.map(ElementID.manual) ?? rendered?.id ?? identity(for: tree)
        let previous = rendered?.id == id ? rendered : nil

        if let rendered = rendered, previous == nil {
            forget(rendered)
        }

        let walked = element(id: id, rendered: previous, node: tree)
        sayAnsweredTwice()
        return walked
    }

    /// The clean walk: no fresh tree, and exactly the elements whose reads intersect
    /// `changed` are built again. Sound only when every cause named its state.
    /// Design: docs/design/core/identity-and-diffing.md#the-clean-walk
    func revisit(
        _ rendered: RenderedNode,
        changed: Set<ObjectIdentifier>
    ) -> (node: RenderedNode, patch: HostPatch) {
        describeAll = false
        buildsEveryView = false
        self.changed = changed
        stylesMoved = false
        walkStamp += 1
        seedScope()

        let walked = revisit(rendered)
        sayAnsweredTwice()
        return walked
    }

    /// A state this element no longer shows: a tie fewer, and its answer for `.inherited` gone with it.
    func untie(_ number: Int32, from id: ElementID) {
        guard let state = Renderer.shared.storage(of: number) else { return }

        state.ties -= 1
        state.answers[id] = nil
    }

    /// Says each driven value two live elements answer `.inherited` for differently - after the walk let go of
    /// what left, so an element replaced in the same render answers nothing.
    /// Design: docs/design/core/identity-and-diffing.md#driven-properties
    private func sayAnsweredTwice() {
        defer { answered = [] }

        for (state, key) in answered {
            let answers = Array(state.answers.values)
            guard let first = answers.first, answers.contains(where: { $0 != first }) else { continue }

            complain("""
                \(key.name) is driven by a value two elements answer \
                differently for. The one described LAST says how it \
                travels.
                """)
        }
    }

    /// One kept element: built again from its placeholder when its reads moved,
    /// walked for changed descendants when they did not.
    func revisit(
        _ rendered: RenderedNode,
        walking: Bool = true
    ) -> (node: RenderedNode, patch: HostPatch) {
        if let placeholder = rendered.placeholder,
            !rendered.reads.isDisjoint(with: changed) {
            return element(
                id: rendered.id,
                rendered: rendered,
                node: placeholder,
                forced: true,
                sizesArrive: rendered.sizesArrive)
        }

        // A composed view walked past is written down only as the path to something
        // built below it, and not for a view just carried.
        let walked = walking && Inspection.recording && !rendered.views.isEmpty
            && Inspection.enter(rendered.views[0].type.name, .walked, element: rendered.id)
        defer { if walked { Inspection.leave() } }

        // And the scene it is in, whose record the kept state below is claimed from.
        let outer = sceneRecord
        if rendered.type == .scene, sceneRecord == nil, case .manual(let name) = rendered.id {
            sceneRecord = OpenScenes.shared.record(id: name)
        }
        defer { sceneRecord = outer }

        var patch = HostPatch(id: rendered.id, type: rendered.type)

        // What this element provided stays in scope while its children are walked.
        scope.append(contentsOf: rendered.provided)
        defer { scope.removeLast(rendered.provided.count) }

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
            leaving.append(contentsOf: registration.handlers.map(\.run))
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

        // Its ties: the states it showed are worn by one element fewer.
        for entry in node.driven.values {
            untie(entry.number, from: node.id)
        }

        for child in node.children {
            forget(child)
        }

        // Its `.onDestroying`, once its subtree's is booked - innermost first.
        leaving.append(contentsOf: node.destroying)
    }

    /// Starts a walk's scope with the standard providers, so any view resolves them
    /// and an app's own `.environment()` below is nearer (StandardEnvironment.swift).
    private func seedScope() {
        scope.removeAll(keepingCapacity: true)
        scope.append(contentsOf: StandardEnvironment.scope)
    }

    // MARK: - Identity

    /// A new element's key: the author's, or a fresh number.
    func identity(for node: Node) -> ElementID {
        node.id.map(ElementID.manual) ?? .auto(allocateElementId())
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
