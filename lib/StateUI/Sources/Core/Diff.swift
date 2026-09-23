// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The differ: what a render built, walked against the tree the host holds, with
// only the differences packed into a `HostPatch`. Element ids and handler ids
// are allocated here, because both outlive the tree that made them.
// Design: docs/design/core/identity-and-diffing.md#keys

/// Walks the authored tree against the rendered one and produces the message.
final class Differ {
    /// The next element id. Never reset, not even by a resync.
    /// Design: docs/design/core/identity-and-diffing.md#ids-are-never-reused
    private var nextElementId = 1

    /// The next handler id, under the same rule.
    private var nextHandlerId = 1

    /// Which walk this is - what tells an aim put on two views in one walk from the
    /// next walk attaching it afresh.
    private var walkStamp = 0

    /// Whether this walk describes every element in full, for a resync. It changes
    /// what goes into the patch, never the matching.
    /// Design: docs/design/core/identity-and-diffing.md#a-resync-keeps-matching
    private var describeAll = false

    /// The style sheet every element this walk builds is resolved against, kept
    /// between walks because a clean walk does not read it (Views/Style.swift).
    private var styles: StyleSheet?

    /// How a changed value animates where its element says nothing else - the
    /// application's answer, or the library's default in a test's differ.
    var motion: Motion = .standard

    /// Whether the sheet moved at the top of this walk, which suppresses every carry
    /// for the walk.
    /// Design: docs/design/core/identity-and-diffing.md#what-a-carry-cannot-see
    private var stylesMoved = false

    /// The states written since the tree the host holds was built - what the clean
    /// walk and the carry decide by.
    private var changed: Set<ObjectIdentifier> = []

    /// What each changed state is called, for `debugInfo()` (Core/Builds.swift).
    var named: [ObjectIdentifier: String] = [:]

    /// The handlers this walk found to run - `.onChanged`, `.onCreated` - in the
    /// order reached, run by the renderer after the walk.
    /// Design: docs/design/core/render.md#handlers-in-the-message
    private var fired: [EventHandler] = []

    /// The `.onDestroying` handlers of what this walk let go, innermost first; they
    /// run before everything in `fired`.
    private var leaving: [EventHandler] = []

    /// The environments in scope where the walk stands, nearest last
    /// (Core/Environment.swift).
    private var scope: [(key: ObjectIdentifier, object: AnyObject)] = []

    /// The composed views whose bodies the walk is inside, outermost first - what a
    /// bare container's content names in `debugInfo()`.
    private var bodies: [String] = []

    /// What every live element's events run, kept between renders: a carried subtree
    /// is not walked, and its handlers must go on working.
    /// Design: docs/design/core/identity-and-diffing.md#handlers-and-their-ids
    private var handlers: [Int: EventHandler] = [:]

    /// The scene the walk is inside, whose record keeps its `@State(sceneKey:)`
    /// boxes; `Scenes.building` follows it.
    private var sceneRecord: SceneRecord? {
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
    private func revisit(
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

    // MARK: - One element

    /// Registers this element's engines, or hands the ones it has this render's
    /// closures; a different count starts over.
    /// Design: docs/design/core/identity-and-diffing.md#engines-on-an-element
    private func arm(
        _ declared: [EngineDeclaration],
        previous: [Int]?
    ) -> [Int] {
        if let previous = previous, previous.count == declared.count {
            var kept = true

            for (id, engine) in zip(previous, declared) {
                kept = Renderer.shared.board(for: engine.sync)
                    .rearm(id, following: engine.follows, with: engine.run) && kept
            }

            // Unless the board forgot them, as after a session claimed afresh: then they
            // are registered again under the numbers they had.
            if kept { return previous }
        }

        for id in previous ?? [] {
            Renderer.shared.disarm(id)
        }

        return declared.map { engine in
            let id = allocateHandlerId()

            Renderer.shared.board(for: engine.sync).arm(EngineEntry(
                id: id,
                priority: engine.priority,
                sync: engine.sync,
                follows: engine.follows,
                run: engine.run))

            return id
        }
    }

    /// Reconciles one element and returns it as it now stands, with the patch that
    /// gets the host there: a composed view carried whole, an element replaced, an
    /// element changed, or one unchanged whose empty patch its parent drops.
    ///
    /// `sizesArrive` says the layout it stands in is measured.
    private func element(
        id: ElementId,
        rendered: RenderedNode?,
        node: Node,
        forced: Bool = false,
        sizesArrive: Bool = false
    ) -> (node: RenderedNode, patch: HostPatch) {
        var node = node

        // Whether an inspector's frame is open for this element (Core/Inspection.swift).
        var inspected = false
        defer { if inspected { Inspection.leave() } }

        var views: [(
            type: String,
            boxes: [(path: String, box: StateBox)],
            inputs: [(path: String, input: Input)])] = []

        // How many times this element has been described, this time included.
        let builds = (rendered?.builds ?? 0) + 1

        // The builder path belongs to where the element was written, so it is read
        // before any placeholder is unwrapped.
        let key = node.key

        // An aim takes the key this element settled on (Core/Aim.swift).
        let written = node.aim
        written?.attach(id, walk: walkStamp)

        // The readings asked for here, keyed by their target and held by this element
        // (Core/Sampling.swift).
        var readings: [Sampling] = []

        for (image, into, asks, take) in node.samples {
            readings.append(image.sample(into: into, every: asks.window, take: take))
        }

        // What `.environment()` provided here joins the scope before anything below
        // resolves; the count is kept for the clean walk.
        var pushed = node.environments.count
        scope.append(contentsOf: node.environments)
        defer { scope.removeLast(pushed) }

        // What the element holds for its life - a page's session - handed back on every
        // build (Core/ElementSession.swift).
        var session: AnyObject?

        if let request = node.session {
            let same = rendered?.views.first?.type == node.stateful?.viewType
            let object = (same ? rendered?.session : nil) ?? request.make()

            request.object = object
            session = object
            scope.append((key: request.type, object: object))
            pushed += 1
        }

        // And which views this element enters, for the containers under it.
        var entered = 0
        defer { bodies.removeLast(entered) }

        // The environments visible at a composed view, which a carry compares.
        // Design: docs/design/core/identity-and-diffing.md#what-a-carry-cannot-see
        var seen: [ObjectIdentifier: ObjectIdentifier] = [:]

        // What the clean walk needs to build this element again without its parent: a
        // composed view keeps its placeholder, a container its node with the content
        // still to run; a leaf keeps nothing.
        // Design: docs/design/core/identity-and-diffing.md#the-clean-walk
        var placeholder = node.stateful != nil || node.producer != nil ? node : nil

        // The node as written, which a leaf wearing a themed value keeps.
        let authored = node

        // Everything the builds below read, recorded against this element.
        var reads: Set<ObjectIdentifier> = []

        // The frame the last body build ran under, for the container content below.
        var frame: BuildScope.Frame?

        // The scene this element is in, held while it and its subtree are built.
        let outerScene = sceneRecord
        defer { sceneRecord = outerScene }

        // Unwraps nested placeholders, outermost first, until a real node comes out.
        while true {
            // A composed view: the same key holding the same kind of view keeps its state,
            // adopted before the body reads it.
            // Design: docs/design/core/identity-and-diffing.md#state-survives-a-rebuild
            if let stateful = node.stateful {
                let step = views.count

                if let record = stateful.scene, sceneRecord == nil {
                    sceneRecord = record
                }

                if let rendered = rendered,
                    step < rendered.views.count,
                    rendered.views[step].type == stateful.viewType {
                    // By path, not by position.
                    // Design: docs/design/core/identity-and-diffing.md#paths-pair-state
                    var kept: [String: StateBox] = [:]

                    for (path, box) in rendered.views[step].boxes where kept[path] == nil {
                        kept[path] = box
                    }

                    for (path, fresh) in stateful.boxes {
                        if let previous = kept[path] {
                            fresh.adopt(from: previous)
                        }
                    }
                }

                // A state a scene keeps takes the scene's storage for its key, before the body
                // reads it (Core/Scenes.swift).
                if let record = sceneRecord {
                    for (_, box) in stateful.boxes {
                        (box as? SceneClaiming)?.claimScene(record)
                    }
                }

                views.append((
                    type: stateful.viewType, boxes: stateful.boxes, inputs: stateful.inputs))

                // Slots resolve against everything provided so far, before the body builds.
                stateful.resolve(from: scope)

                // A composed view built with the same inputs that read nothing that moved is
                // carried whole; decided on the outermost view alone.
                // Design: docs/design/core/identity-and-diffing.md#carrying-a-view
                if step == 0 {
                    seen = snapshot()

                    if let rendered = rendered, !forced, !describeAll, !stylesMoved,
                        let kept = rendered.views.first,
                        kept.type == stateful.viewType,
                        rendered.reads.isDisjoint(with: changed),
                        rendered.seen == seen,
                        let wrote = rendered.placeholder,
                        sameWriting(node, as: wrote),
                        Input.same(stateful.inputs, kept.inputs) {
                        if Inspection.recording {
                            inspected = Inspection.enter(
                                stateful.viewType, .carried, element: id)
                        }

                        return carry(rendered, written: node)
                    }

                    if Inspection.recording {
                        inspected = Inspection.enter(
                            stateful.viewType,
                            .built(reason(stateful, node: node, rendered: rendered, seen: seen)),
                            element: id)
                    }
                }

                let built = BuildScope.Frame(
                    view: stateful.viewType,
                    builds: builds,
                    read: rendered?.reads ?? [],
                    changed: self.changed,
                    names: self.named,
                    everything: describeAll)

                frame = built
                bodies.append(stateful.viewType)
                entered += 1

                node = ReadScope.collect(into: &reads) {
                    BuildScope.within(built) { stateful.expand(over: node) }
                }
                pushed += node.environments.count
                scope.append(contentsOf: node.environments)
                continue
            }

            break
        }

        // A scene written as a node rather than a scene type - a test's own tree.
        if node.type == .scene, sceneRecord == nil, case .manual(let name) = id {
            sceneRecord = Scenes.shared.record(id: name)
        }

        // The container's own content runs here, inside this element's read scope and
        // build frame: the reader of a state is the closure that read it.
        // Design: docs/design/core/identity-and-diffing.md#containers-run-their-own-content
        let within = frame ?? bareFrame(for: rendered, builds: builds)

        // A container built again for what its own closure read: an inspector names the
        // view and the container.
        if Inspection.recording, forced, views.isEmpty {
            let owner = Inspection.short(within?.view ?? "a view")

            inspected = Inspection.enter(
                "\(owner) › \(node.type.name)",
                .built("for " + names(of: (rendered?.reads ?? []).intersection(changed))),
                element: id)
        }

        node = ReadScope.collect(into: &reads) {
            let shallow = { () -> Node in
                var made = node
                made.materialize()
                return made
            }

            guard let within else { return shallow() }

            return BuildScope.within(within, shallow)
        }

        // An aim on the root of a composed view's content is the same element.
        if let inner = node.aim, inner !== written {
            inner.attach(id, walk: walkStamp)
        }

        // The same for a reading written on that root.
        for (image, into, asks, take) in node.samples {
            readings.append(image.sample(into: into, every: asks.window, take: take))
        }

        // The style is applied here, so a host receives every value already on the
        // control (Views/Style.swift).
        node = styled(node, with: styles)

        // Themed values are picked here, which makes this element the theme's reader.
        // Design: docs/design/core/identity-and-diffing.md#themes
        if node.props.values.contains(where: \.isThemed) {
            node.props = ReadScope.collect(into: &reads) {
                node.props.mapValues { $0.isThemed ? $0.resolvingTheme() : $0 }
            }

            if placeholder == nil {
                placeholder = authored
            }
        }

        // The engines this element runs, under numbers it keeps; a conversion's engines
        // come first, in property order.
        // Design: docs/design/core/identity-and-diffing.md#engines-on-an-element
        let converting = node.driven.keys.sorted()
            .compactMap { node.driven[$0]!.conversion }
            .flatMap { $0.declarations() }
        let engines = arm(converting + node.engines, previous: rendered?.engines)

        // Properties described last render and not now are named for the host to clear.
        // Design: docs/design/core/identity-and-diffing.md#properties-no-longer-described
        let lost = (rendered?.props.keys.filter { node.props[$0] == nil } ?? []).sorted()

        // Except those with no host default, which replace the element.
        let replace = rendered != nil
            && (rendered!.type != node.type || lost.contains { !$0.facts.cleared })

        // Nothing to build on: the element is new, or cannot become what is described.
        let previous = replace ? nil : rendered

        if replace, let rendered = rendered {
            forget(rendered)
        }

        var patch = HostPatch(id: id, type: node.type)
        patch.replace = replace
        patch.fresh = describeAll || previous == nil

        // How this element's values animate: its own plan, or the application's.
        let plan = node.motion
        let standing = motion
        let travel = { (values: MotionValues) in
            (plan?.motion(for: values) ?? .inherited).resolved(against: standing)
        }

        // What values with no kind of their own animate at.
        let travels = travel(.all)

        // An element that places children, has visual states, or answered `.motion(_:)`
        // for itself says how its children animate; `.inherited`, the default on both
        // sides, is never said.
        // Design: docs/design/core/identity-and-diffing.md#layout-motion
        if NodeType.saysMotion.contains(node.type)
            || node.states
            || plan?.base != nil {
            let mine = node.type == .application
                ? motion
                : (plan?.motion(for: .place).map { $0.isInherited ? .inherited : $0 }
                    ?? .inherited)

            // Inherited until told otherwise; the application says its own once.
            let was: Motion? = node.type == .application
                ? (describeAll ? nil : previous?.motion)
                : (describeAll ? .inherited : (previous?.motion ?? .inherited))

            // Which parts of a child's place animate.
            var lanes = MotionLanes.all

            if travel(.place).isNothing { lanes.subtract(.place) }
            if travel(.width).isNothing { lanes.subtract(.width) }
            if travel(.height).isNothing { lanes.subtract(.height) }

            // A measured layout's children take their sizes at once.
            if node.childSizesArrive { lanes.subtract([.width, .height]) }

            let stood = describeAll ? MotionLanes.all : (previous?.lanes ?? .all)

            if was != mine || stood != lanes {
                patch.motion = HostLayoutMotion(motion: mine, lanes: lanes)
            }
        }

        if node.recycles != (describeAll ? false : (previous?.recycles ?? false)) {
            patch.recycles = node.recycles
        }

        // Nothing is cleared on an element described from scratch.
        patch.clearedProperties = replace ? [] : lost

        // `.onChanged` against what this continuing element carried last time; a
        // different count starts over.
        // Design: docs/design/core/identity-and-diffing.md#watching-values
        if let previous = previous, previous.watched.count == node.watches.count {
            for (index, watch) in node.watches.enumerated() {
                let old = previous.watched[index]

                // Nil: the stored value is of another type, and the slot starts over.
                if watch.matches(old) == false {
                    let new = watch.value
                    fired.append { try await watch.run(old, new) }
                }
            }
        }

        // `.onCreated` for an element that was not here.
        // Design: docs/design/core/identity-and-diffing.md#created-and-destroying
        if previous == nil {
            fired.append(contentsOf: node.created)

            // A node type the host does not realize is said once, with near misses.
            if let unrealized = HostRealizations.unrealized(node.type) {
                complain(unrealized)
            }
        }

        // Every property when there is nothing to compare against, or on a resync.
        let changed = previous.map { was in
            node.props.filter { key, value in was.props[key] != value }
        } ?? node.props

        patch.properties = describeAll ? node.props : changed

        // A property that changed on a continuing element animates to its new value; a
        // measured size arrives at once.
        // Design: docs/design/core/identity-and-diffing.md#transitions
        let measured = sizesArrive || node.reportsFrame

        if !describeAll, !replace, previous != nil, plan != nil || !travels.isNothing {
            for (property, value) in patch.properties
            where value.moves && property.facts.travels
                && patch.transitions[property] == nil {
                if measured, !property.facts.moves.isDisjoint(with: [.width, .height]) { continue }

                let moves = travel(value.kind.union(property.facts.moves))

                if moves.isNothing { continue }

                patch.transitions[property] = HostTransition(motion: moves)
            }
        }

        // Handler ids are kept per event, assigned in name order.
        // Design: docs/design/core/identity-and-diffing.md#handlers-and-their-ids
        var events: [Event: Int] = [:]
        for (name, handler) in node.events.sorted(by: { $0.key < $1.key }) {
            let handlerId = previous?.events[name] ?? allocateHandlerId()
            events[name] = handlerId
            handlers[handlerId] = handler
        }

        if let previous = previous {
            // An event this element no longer handles takes its id with it.
            for (name, handlerId) in previous.events where events[name] == nil {
                handlers.removeValue(forKey: handlerId)
            }
        }

        // Sent when the handled set changed; an empty map only for a continuing element.
        let eventsChanged = describeAll || previous == nil
            ? !events.isEmpty
            : Set(events.keys) != Set(previous!.events.keys)

        if eventsChanged {
            patch.events = .replace(events.mapValues { Int32($0) })
        }

        // The properties driven to a state, numbered in walk and name order; the set is
        // sent whenever it changed, an emptied one included.
        // Design: docs/design/core/identity-and-diffing.md#driven-properties
        var driven: [Prop: StateEntry] = [:]

        for key in node.driven.keys.sorted() {
            let registration = node.driven[key]!
            let state = registration.state

            // What `.inherited` means on this value can be answered only here; the answer
            // stays on the state and is read at the crossing.
            let mine = travel(key.facts.moves.union(registration.values))

            if let already = state.inheritedBy, already != id, state.inherited != mine {
                complain("""
                    \(key.name) is driven by a value two elements answer \
                    differently for. The one described LAST says how it \
                    travels.
                    """)
            }

            state.inherited = mine
            state.inheritedBy = id
            state.door = registration.kind

            driven[key] = StateEntry(
                number: Renderer.shared.number(for: state),
                mode: registration.mode,
                kind: registration.kind)
        }

        let tiesChanged = describeAll || previous == nil
            ? !driven.isEmpty
            : driven != previous!.driven

        if tiesChanged {
            patch.driven = .replace(driven.mapValues(HostStateBinding.init))
        }

        let children = reconcileChildren(
            of: previous, node: node, into: &patch, sizesArrive: node.childSizesArrive)

        let result = RenderedNode(
            id: id,
            type: node.type,
            props: node.props,
            events: events,
            recycles: node.recycles,
            motion: patch.motion?.motion ?? previous?.motion ?? .inherited,
            lanes: patch.motion?.lanes ?? previous?.lanes ?? .all,
            key: key,
            views: views,
            placeholder: placeholder,
            view: within?.view,
            reads: reads,
            builds: builds,
            provided: Array(scope.suffix(pushed)),
            seen: seen,
            watched: node.watches.map { $0.value },
            engines: engines,
            driven: driven,
            readings: readings,
            children: children
        )
        result.sizesArrive = sizesArrive

        // What it runs as it leaves: this build's closures, the newest.
        result.destroying = node.destroying
        result.session = session

        return (result, patch)
    }

    /// The frame a bare container's content runs under: the view the walk is in,
    /// with this element's own count and reads.
    private func bareFrame(for rendered: RenderedNode?, builds: Int) -> BuildScope.Frame? {
        guard let view = bodies.last ?? rendered?.view else { return nil }

        return BuildScope.Frame(
            view: view,
            builds: builds,
            read: rendered?.reads ?? [],
            changed: changed,
            names: named,
            everything: describeAll)
    }

    /// Why a composed view is built rather than carried, in words - the carry's
    /// questions in the carry's order. Asked only while an inspector records.
    private func reason(
        _ stateful: Node.Stateful,
        node: Node,
        rendered: RenderedNode?,
        seen: [ObjectIdentifier: ObjectIdentifier]
    ) -> String {
        guard let rendered else { return "first time" }

        let causes = rendered.reads.intersection(changed)

        if !causes.isEmpty {
            return "for " + names(of: causes)
        }

        if describeAll {
            return "the whole tree"
        }

        guard let kept = rendered.views.first, kept.type == stateful.viewType else {
            return "a different view here"
        }

        if stylesMoved {
            return "the styles moved"
        }

        if rendered.seen != seen {
            return "an environment it sees was replaced"
        }

        if let wrote = rendered.placeholder, !sameWriting(node, as: wrote) {
            return "its parent wrote it differently"
        }

        if let input = Input.difference(stateful.inputs, kept.inputs) {
            return "built with a new \(input)"
        }

        return "with its parent"
    }

    /// States by the names their authors gave them, in name order.
    private func names(of states: Set<ObjectIdentifier>) -> String {
        states.map { named[$0] ?? "state" }.sorted().joined(separator: ", ")
    }

    // MARK: - Children

    /// Matches this render's children against the last one's and patches each. An
    /// unchanged key sequence sends only the children with something to say; a
    /// changed one sends the complete list in order.
    /// Design: docs/design/core/identity-and-diffing.md#keys
    private func reconcileChildren(
        of previous: RenderedNode?,
        node: Node,
        into patch: inout HostPatch,
        sizesArrive: Bool
    ) -> [RenderedNode] {
        let rendered = previous?.children ?? []

        var byManualId: [String: RenderedNode] = [:]
        var byKey: [String: RenderedNode] = [:]
        for child in rendered {
            if case .manual(let key) = child.id {
                byManualId[key] = child
            }

            // First wins, so two elements claiming one path behave like a repeated `.id()`.
            if let key = child.key, byKey[key] == nil {
                byKey[key] = child
            }
        }

        // Nodes put in by hand are matched by position among themselves.
        let unkeyed = rendered.filter { $0.key == nil }

        var children: [RenderedNode] = []
        var patches: [HostPatch] = []
        var claimed: Set<ElementId> = []
        var used: Set<ElementId> = []
        var unkeyedSoFar = 0
        var manualSeen: [String: Int] = [:]

        for (index, childNode) in node.children.enumerated() {
            // A repeated `.id()` takes a stable variant: the id, a NUL, its occurrence.
            // Design: docs/design/core/identity-and-diffing.md#repeated-ids
            var childNode = childNode
            if let rawId = childNode.id {
                let occurrence = manualSeen[rawId, default: 0]
                manualSeen[rawId] = occurrence + 1

                if occurrence > 0 {
                    childNode.id = "\(rawId)\u{0}\(occurrence)"
                }
            }

            let match = self.match(
                childNode,
                at: childNode.key == nil ? unkeyedSoFar : index,
                rendered: unkeyed,
                byManualId: byManualId,
                byKey: byKey,
                claimed: claimed)

            if childNode.key == nil {
                unkeyedSoFar += 1
            }

            if let match = match {
                claimed.insert(match.id)
            }

            var id = match?.id ?? identity(for: childNode)

            // A backstop for a variant that still collided, which it should not.
            if used.contains(id) {
                id = .auto(allocateElementId())
            }

            used.insert(id)

            var (child, childPatch) = element(
                id: id, rendered: match, node: childNode, sizesArrive: sizesArrive)

            // What this row looks like, under a layout whose rows are recycled; sent when
            // it moved.
            // Design: docs/design/core/identity-and-diffing.md#recycling
            if node.recycles {
                child.shape = Recycling.shape(of: child)

                // Against the host's default on a complete description.
                let had = describeAll ? Recycling.none : (match?.shape ?? Recycling.none)

                if child.shape != had {
                    childPatch.shape = child.shape
                }
            }

            children.append(child)
            patches.append(childPatch)
        }

        for child in rendered where !claimed.contains(child.id) {
            forget(child)
        }

        // The arrangement is sent only when it changed.
        if describeAll || children.map(\.id) != rendered.map(\.id) {
            patch.children = .arranged(patches)
        } else {
            let changed = patches.filter { !$0.isEmpty }
            patch.children = changed.isEmpty ? .unchanged : .changed(changed)
        }

        return children
    }

    /// The rendered element a node continues: by the author's `.id()`, then by the
    /// builder path, then by position - three ways that never meet.
    /// Design: docs/design/core/identity-and-diffing.md#keys
    private func match(
        _ node: Node,
        at index: Int,
        rendered: [RenderedNode],
        byManualId: [String: RenderedNode],
        byKey: [String: RenderedNode],
        claimed: Set<ElementId>
    ) -> RenderedNode? {
        if let id = node.id {
            let match = byManualId[id]
            return match.flatMap { claimed.contains($0.id) ? nil : $0 }
        }

        if let key = node.key {
            let match = byKey[key]
            return match.flatMap {
                claimed.contains($0.id) || $0.id.isManual ? nil : $0
            }
        }

        guard index < rendered.count else { return nil }

        let candidate = rendered[index]

        guard case .auto = candidate.id, !claimed.contains(candidate.id) else {
            return nil
        }

        return candidate
    }

    // MARK: - Environment

    /// Starts a walk's scope with the standard providers, so any view resolves them
    /// and an app's own `.environment()` below is nearer (Types/HostEnvironment.swift).
    private func seedScope() {
        scope.removeAll(keepingCapacity: true)
        scope.append(contentsOf: StandardEnvironment.scope)
    }

    /// Whether the parent wrote the same things on a composed view as last render.
    /// Design: docs/design/core/identity-and-diffing.md#what-the-parent-wrote
    private func sameWriting(_ node: Node, as kept: Node) -> Bool {
        guard node.props == kept.props,
            node.motion == kept.motion,
            node.children.isEmpty, kept.children.isEmpty,
            node.engines.isEmpty, kept.engines.isEmpty,
            node.samples.isEmpty, kept.samples.isEmpty,
            Set(node.events.keys) == Set(kept.events.keys),
            node.watches.count == kept.watches.count,
            node.created.count == kept.created.count,
            node.destroying.count == kept.destroying.count,
            node.environments.count == kept.environments.count,
            node.driven.count == kept.driven.count
        else { return false }

        for (fresh, old) in zip(node.watches, kept.watches)
        where fresh.matches(old.value) != true {
            return false
        }

        for (fresh, old) in zip(node.environments, kept.environments)
        where fresh.key != old.key || fresh.object !== old.object {
            return false
        }

        for (key, fresh) in node.driven {
            guard let old = kept.driven[key],
                fresh.state === old.state,
                fresh.kind == old.kind,
                fresh.mode == old.mode,
                fresh.values == old.values,
                fresh.conversion == nil,
                old.conversion == nil
            else { return false }
        }

        return true
    }

    /// Carries a composed element whose inputs, reads and writing all held: nothing
    /// under it is built, and the handlers the parent wrote on it are taken fresh.
    /// Design: docs/design/core/identity-and-diffing.md#what-the-parent-wrote
    private func carry(
        _ rendered: RenderedNode,
        written node: Node
    ) -> (node: RenderedNode, patch: HostPatch) {
        for (name, handler) in node.events {
            if let id = rendered.events[name] {
                handlers[id] = handler
            }
        }

        // Its `.onDestroying`: its body's last ones, then the parent's, taken fresh.
        rendered.destroying =
            Array(rendered.destroying.dropLast(node.destroying.count)) + node.destroying

        rendered.placeholder = node

        return revisit(rendered, walking: false)
    }

    /// The nearest provided object per type, by identity - what a carry compares.
    private func snapshot() -> [ObjectIdentifier: ObjectIdentifier] {
        var seen: [ObjectIdentifier: ObjectIdentifier] = [:]

        for entry in scope {
            seen[entry.key] = ObjectIdentifier(entry.object)
        }

        return seen
    }

    // MARK: - Identity

    /// A new element's key: the author's, or a fresh number.
    private func identity(for node: Node) -> ElementId {
        node.id.map(ElementId.manual) ?? .auto(allocateElementId())
    }

    /// The next element id. Never reused.
    private func allocateElementId() -> Int {
        let id = nextElementId
        nextElementId += 1
        return id
    }

    /// The next handler id. Never reused.
    private func allocateHandlerId() -> Int {
        let id = nextHandlerId
        nextHandlerId += 1
        return id
    }
}
