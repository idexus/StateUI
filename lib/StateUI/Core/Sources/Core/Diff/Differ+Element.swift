// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// One element reconciled: its composed views carried or built, its properties,
// events, engines and driven states compared, and the patch that says so.
// Design: docs/design/core/identity-and-diffing.md#carrying-a-view

extension Differ {
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
    func element(
        id: ElementID,
        rendered: RenderedNode?,
        node: Node,
        forced: Bool = false,
        sizesArrive: Bool = false
    ) -> (node: RenderedNode, patch: HostPatch) {
        var node = node

        // Whether this is the view a page shows (PageValues.swift).
        let atPageRoot = describesPageRoot
        describesPageRoot = false

        // Whether an inspector's frame is open for this element
        // (Inspection.swift).
        var inspected = false
        defer { if inspected { Inspection.leave() } }

        var views: [(
            type: String,
            boxes: [(path: String, box: StateBox)],
            inputs: [(path: String, input: Input)],
            branch: String?)] = []

        // How many times this element has been described, this time included.
        let builds = (rendered?.builds ?? 0) + 1

        // The builder path belongs to where the element was written, so it is read
        // before any placeholder is unwrapped.
        let key = node.key

        // An aim takes the key this element settled on (Aim.swift).
        let written = node.aim
        written?.attach(id, walk: walkStamp)

        // The readings asked for here, keyed by their target and held by this element
        // (Sampling.swift).
        var readings: [Sampling] = []

        for (image, into, asks, take) in node.samples {
            readings.append(image.sample(into: into, every: asks.window, take: take))
        }

        // What `.environment()` provided here joins the scope before anything below
        // resolves; the count is kept for the clean walk.
        var pushed = node.environments.count
        scope.append(contentsOf: node.environments)
        defer { scope.removeLast(pushed) }

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

        // The derived states its builds made or found, which it holds.
        var derived: [AnyObject] = []

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
                // reads it (SceneRecord.swift).
                if let record = sceneRecord {
                    for (_, box) in stateful.boxes {
                        (box as? SceneClaiming)?.claimScene(record)
                    }
                }

                views.append((
                    type: stateful.viewType, boxes: stateful.boxes, inputs: stateful.inputs, branch: nil))

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
                    written: self.written,
                    everything: describeAll,
                    element: id)

                frame = built
                bodies.append(stateful.viewType)
                entered += 1

                node = ReadScope.collect(into: &reads) {
                    DerivationScope.collect(into: &derived) {
                        BuildScope.within(built) { stateful.expand(over: node) }
                    }
                }
                views[step].branch = node.branch
                pushed += node.environments.count
                scope.append(contentsOf: node.environments)
                continue
            }

            break
        }

        // What the view says of its page: the page takes it where this is the view it shows, an arrangement standing
        // where a page stands its title and icon; anywhere else it says nothing.
        // Design: docs/design/views/pages.md#what-a-view-says-of-its-page
        let pageValues = node.pageValues
        node.pageValues = nil
        if let pageValues, !atPageRoot {
            node.takeAsArrangement(pageValues)
        }

        // An arrangement keeps what its contract declares (Differ+Arrangements.swift).
        node.keepingDeclared()

        // A scene written as a node rather than a scene type - a test's own tree.
        if node.type == .scene, sceneRecord == nil, case .manual(let name) = id {
            sceneRecord = OpenScenes.shared.record(id: name)
        }

        // The container's own content runs here, inside this element's read scope and
        // build frame: the reader of a state is the closure that read it.
        // Design: docs/design/core/identity-and-diffing.md#containers-run-their-own-content
        let within = frame ?? bareFrame(for: rendered, builds: builds, element: id)

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

            return DerivationScope.collect(into: &derived) { BuildScope.within(within, shallow) }
        }

        // A page describes the view it shows first, and says what that view says of it; it reads all that view's
        // own build read, so a write the view's page values follow describes the page again.
        // Design: docs/design/views/pages.md#what-a-view-says-of-its-page
        var described: (children: [RenderedNode], patch: HostPatch)?
        if node.type == .page {
            let reshaped = rendered.map { $0.type != node.type || Self.kinds($0.views) != Self.kinds(views) } ?? false
            var holder = HostPatch(id: id, type: node.type)
            describesPageRoot = true
            let children = reconcileChildren(
                of: reshaped ? nil : rendered, node: node, into: &holder, sizesArrive: node.childSizesArrive)
            describesPageRoot = false

            if let root = children.first {
                reads.formUnion(root.reads)
                if let said = root.pageValues { node.take(said) }
            }
            described = (children, holder)
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
        // control (StyleSheet.swift).
        node = styled(node, with: styles)

        // And its visual states resolved, the element reading what they follow.
        // Design: docs/design/views/styles.md#which-state-a-control-is-in
        let visualInput = node.visualStates.isEmpty ? nil : (rendered?.visualInput ?? VisualInput())
        var visualState: String?
        let runs = rendered?.runs ?? RunSlots()

        if let visualInput {
            visualState = resolveVisualStates(
                &node, input: visualInput, previous: rendered?.visualState, runs: runs, reads: &reads)

            if placeholder == nil {
                placeholder = authored
            }
        }

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

        // Except those with no host default, which replace the element - as a view of another kind does.
        // Design: docs/design/core/identity-and-diffing.md#another-kind-of-view
        let replace = rendered != nil
            && (rendered!.type != node.type || Self.kinds(rendered!.views) != Self.kinds(views)
                || lost.contains { !$0.facts.cleared })

        // Nothing to build on: the element is new, or cannot become what is described.
        let previous = replace ? nil : rendered

        // The runs of what this element's walks find, kept while it is the same element.
        let kept = replace ? RunSlots() : runs

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

        // An element that places children or answered `.motion(_:)` for itself says how
        // its children animate; `.inherited`, the default on both sides, is never said.
        // Design: docs/design/core/identity-and-diffing.md#layout-motion
        if NodeType.saysMotion.contains(node.type)
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
                    fired.append(Fired(
                        run: { try await watch.run(old, new) }, repeated: watch.repeated,
                        slot: kept.slot("watch \(index)")))
                }
            }
        }

        // `.onCreated` for an element that was not here.
        // Design: docs/design/core/identity-and-diffing.md#created-and-destroying
        if previous == nil {
            for (index, created) in node.created.enumerated() {
                fired.append(Fired(run: created, repeated: .overlap, slot: kept.slot("created \(index)")))
            }

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
        for (name, written) in node.events.sorted(by: { $0.key < $1.key }) {
            let handlerId = previous?.events[name] ?? allocateHandlerId()
            events[name] = handlerId
            register(written, under: handlerId)
        }

        if let previous = previous {
            // An event this element no longer handles takes its id and its runs with it.
            for (name, handlerId) in previous.events where events[name] == nil {
                handlers.removeValue(forKey: handlerId)?.orphan()
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
            state.laneKind = registration.laneKind

            driven[key] = StateEntry(
                number: Renderer.shared.number(for: state),
                mode: registration.mode,
                kind: registration.kind,
                laneKind: registration.laneKind)
        }

        let tiesChanged = describeAll || previous == nil
            ? !driven.isEmpty
            : driven != previous!.driven

        if tiesChanged {
            patch.driven = .replace(driven.mapValues(HostStateBinding.init))
        }

        let children: [RenderedNode]
        if let described {
            children = described.children
            patch.children = described.patch.children
        } else {
            children = reconcileChildren(of: previous, node: node, into: &patch, sizesArrive: node.childSizesArrive)
        }

        let result = RenderedNode(
            id: id,
            type: node.type,
            props: node.props,
            events: events,
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
            derived: derived,
            children: children
        )
        result.sizesArrive = sizesArrive
        result.visualInput = visualInput
        result.runs = kept
        result.visualState = visualState

        // What it says of the page it is the view of.
        result.pageValues = atPageRoot ? pageValues : nil

        // What it runs as it leaves: this build's closures, the newest.
        result.destroying = node.destroying

        return (result, patch)
    }

    /// The frame a bare container's content runs under: the view the walk is in,
    /// with this element's own count and reads.
    private func bareFrame(for rendered: RenderedNode?, builds: Int, element: ElementID) -> BuildScope.Frame? {
        guard let view = bodies.last ?? rendered?.view else { return nil }

        return BuildScope.Frame(
            view: view,
            builds: builds,
            read: rendered?.reads ?? [],
            changed: changed,
            written: written,
            everything: describeAll,
            element: element)
    }

    /// What an element is by its composed views: each one's type and the branch its content root stood in.
    /// Design: docs/design/core/identity-and-diffing.md#another-kind-of-view
    private static func kinds(_ views: [(
        type: String,
        boxes: [(path: String, box: StateBox)],
        inputs: [(path: String, input: Input)],
        branch: String?)]) -> [String] {
        views.map { view in view.branch.map { "\(view.type) \($0)" } ?? view.type }
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
        states.map { BuildScope.name(of: written[$0]) }.sorted().joined(separator: ", ")
    }

    /// Whether two writings say the same of their page.
    private func samePageValues(_ fresh: PageValues?, _ kept: PageValues?) -> Bool {
        switch (fresh, kept) {
        case (nil, nil): return true
        case let (fresh?, kept?): return sameWriting(fresh.node, as: kept.node)
        default: return false
        }
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
            node.driven.count == kept.driven.count,
            samePageValues(node.pageValues, kept.pageValues)
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

    /// Keeps `written` under `id`: an id an element keeps keeps its handlers' runs.
    private func register(_ written: [Handler], under id: Int) {
        if let registered = handlers[id] {
            registered.replace(written)
        } else {
            handlers[id] = EventRegistration(written)
        }
    }

    /// Carries a composed element whose inputs, reads and writing all held: nothing
    /// under it is built, and the handlers the parent wrote on it are taken fresh.
    /// Design: docs/design/core/identity-and-diffing.md#what-the-parent-wrote
    private func carry(
        _ rendered: RenderedNode,
        written node: Node
    ) -> (node: RenderedNode, patch: HostPatch) {
        for (name, written) in node.events {
            if let id = rendered.events[name] {
                register(written, under: id)
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
}
