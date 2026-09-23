// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The differ: what a render built, walked against the tree the host holds, with
// only the differences packed into a `HostPatch`. Element ids and handler ids
// are allocated here, because both outlive the tree that made them.
// Design: docs/design/core/identity-and-diffing.md#keys

/// Walks the authored tree against the rendered one and produces the message.
/// Design: docs/design/core/identity-and-diffing.md#what-a-walk-keeps
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

    /// The states written since the tree the host holds was built.
    private(set) var changed: Set<ObjectIdentifier> = []

    /// What each changed state is called, for `debugInfo()` (Core/Render/Builds.swift).
    var named: [ObjectIdentifier: String] = [:]

    /// The handlers this walk found to run - `.onChanged`, `.onCreated` - in order.
    /// Design: docs/design/core/render.md#handlers-in-the-message
    var fired: [EventHandler] = []

    /// The `.onDestroying` handlers of what this walk let go, innermost first.
    private var leaving: [EventHandler] = []

    /// The environments in scope where the walk stands, nearest last.
    var scope: [(key: ObjectIdentifier, object: AnyObject)] = []

    /// The composed views whose bodies the walk is inside, outermost first.
    var bodies: [String] = []

    /// What every live element's events run, kept between renders.
    /// Design: docs/design/core/identity-and-diffing.md#handlers-and-their-ids
    var handlers: [Int: EventHandler] = [:]

    /// The scene the walk is inside; `Scenes.building` follows it.
    var sceneRecord: SceneRecord? {
        didSet { Scenes.shared.building = sceneRecord }
    }

    /// Reconciles the tree just built against the one the host holds. `describeAll`
    /// makes the patch complete while matching stays as it always is; a nil
    /// `rendered` is only for a first render.
    func reconcile(
        _ rendered: RenderedNode?,
        with tree: Node,
        styles: StyleSheet? = nil,
        describeAll: Bool = false,
        changed: Set<ObjectIdentifier> = []
    ) -> (node: RenderedNode, patch: HostPatch) {
        self.describeAll = describeAll
        self.changed = changed
        stylesMoved = !StyleSheet.same(styles, self.styles)
        self.styles = styles
        walkStamp += 1
        seedScope()

        // The root keeps whatever key it was given until the author states another.
        let id = tree.id.map(ElementId.manual) ?? rendered?.id ?? identity(for: tree)
        let previous = rendered?.id == id ? rendered : nil

        if let rendered = rendered, previous == nil {
            forget(rendered)
        }

        return element(id: id, rendered: previous, node: tree)
    }

    /// The clean walk: no fresh tree, and exactly the elements whose reads intersect
    /// `changed` are built again. Sound only when every cause named its state.
    /// Design: docs/design/core/identity-and-diffing.md#the-clean-walk
    func revisit(
        _ rendered: RenderedNode,
        changed: Set<ObjectIdentifier>
    ) -> (node: RenderedNode, patch: HostPatch) {
        describeAll = false
        self.changed = changed
        stylesMoved = false
        walkStamp += 1
        seedScope()

        return revisit(rendered)
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
            && Inspection.enter(rendered.views[0].type, .walked, element: rendered.id)
        defer { if walked { Inspection.leave() } }

        // And the scene it is in, whose record the kept state below is claimed from.
        let outer = sceneRecord
        if rendered.type == .scene, sceneRecord == nil, case .manual(let name) = rendered.id {
            sceneRecord = Scenes.shared.record(id: name)
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
    func handler(_ id: Int) -> EventHandler? {
        handlers[id]
    }

    /// The handlers the last walk found - what left first, then the rest - taken so
    /// each runs once.
    func takeFired() -> [EventHandler] {
        let taken = leaving + fired
        leaving.removeAll(keepingCapacity: true)
        fired.removeAll(keepingCapacity: true)
        return taken
    }

    /// Drops the handlers and engines of an element that left the tree, and of
    /// everything under it, and books its `.onDestroying`.
    func forget(_ node: RenderedNode) {
        for id in node.events.values {
            handlers.removeValue(forKey: id)
        }

        // Its engines: nothing is left to ask for their frames.
        for id in node.engines {
            Renderer.shared.disarm(id)
        }

        for child in node.children {
            forget(child)
        }

        // Its `.onDestroying`, once its subtree's is booked - innermost first.
        leaving.append(contentsOf: node.destroying)
    }

    /// Starts a walk's scope with the standard providers, so any view resolves them
    /// and an app's own `.environment()` below is nearer (Types/HostEnvironment.swift).
    private func seedScope() {
        scope.removeAll(keepingCapacity: true)
        scope.append(contentsOf: StandardEnvironment.scope)
    }

    // MARK: - Identity

    /// A new element's key: the author's, or a fresh number.
    func identity(for node: Node) -> ElementId {
        node.id.map(ElementId.manual) ?? .auto(allocateElementId())
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
