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
            // are registered again under fresh numbers, which the element keeps from then on.
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
    /// `sizesArrive` says the layout it stands in is measured. The walk goes down the tree through this frame,
    /// kept small: the element's work is done in steps that return before its children are walked.
    /// Design: docs/design/core/identity-and-diffing.md#the-walks-stack
    func element(
        id: ElementID,
        rendered: RenderedNode?,
        node: Node,
        forced: Bool = false,
        sizesArrive: Bool = false
    ) -> (node: RenderedNode, patch: HostPatch) {
        let pass = ElementPass(
            id: id, rendered: rendered, node: node, forced: forced, sizesArrive: sizesArrive,
            atPageRoot: describesPageRoot, outerScene: sceneRecord)
        describesPageRoot = false

        // What the element entered - the environments provided, the views, its scene, an inspector's frame - is
        // left once it and its subtree are done.
        defer {
            sceneRecord = pass.outerScene
            bodies.removeLast(pass.entered)
            scope.removeLast(pass.pushed)
            if pass.inspected { Inspection.leave() }
        }

        if let carried = expand(pass) { return carried }
        if pass.node.type == .page { describePage(pass) }
        prepare(pass)

        let children: [RenderedNode]
        if let described = pass.described {
            children = described.children
            pass.patch.children = described.patch.children
        } else {
            children = reconcileChildren(
                of: pass.previous, node: pass.node, into: &pass.patch, sizesArrive: pass.node.childSizesArrive)
        }
        return finish(pass, children: children)
    }

    /// The element's composed views unwrapped, outermost first, until a real node comes out - each keeping its state
    /// and built, or the outermost carried whole - and that node's own content run: the carried element, or nil for
    /// one the steps go on with.
    @inline(never)
    private func expand(_ pass: ElementPass) -> (node: RenderedNode, patch: HostPatch)? {
        let (id, rendered, forced) = (pass.id, pass.rendered, pass.forced)
        var node = pass.node

        // An aim takes the key this element settled on (Aim.swift).
        pass.written?.attach(id, walk: walkStamp)

        // The readings asked for here, keyed by their target and held by this element
        // (Sampling.swift).
        for (image, into, asks, take) in node.samples {
            pass.readings.append(image.sample(into: into, every: asks.window, take: take))
        }

        // What `.environment()` provided here joins the scope before anything below
        // resolves; the count is kept for the clean walk.
        pass.pushed = node.environments.count
        scope.append(contentsOf: node.environments)

        // Unwraps nested placeholders, outermost first, until a real node comes out.
        while true {
            // A composed view: the same key holding the same kind of view keeps its state,
            // adopted before the body reads it.
            // Design: docs/design/core/identity-and-diffing.md#state-survives-a-rebuild
            if let stateful = node.stateful {
                let step = pass.views.count

                if let record = stateful.scene, sceneRecord == nil {
                    sceneRecord = record
                }

                // A view lying byte for byte as its predecessor holds what that held: its walk is the
                // predecessor's, its boxes already the ones kept.
                // Design: docs/design/core/identity-and-diffing.md#a-view-built-as-it-was
                // Every view outside it the same, from the same branch: another branch is another view.
                if let rendered = rendered,
                    step < rendered.views.count,
                    rendered.views[step].type == stateful.viewType,
                    Self.sameKinds(Array(rendered.views.prefix(step)), Array(pass.views.prefix(step))),
                    !stateful.walk.takes(rendered.views[step].walk) {
                    // By path, not by position.
                    // Design: docs/design/core/identity-and-diffing.md#paths-pair-state
                    var kept: [PathNumber: StateBox] = [:]

                    for (path, box) in rendered.views[step].boxes where kept[path] == nil {
                        kept[path] = box
                    }

                    for (path, fresh) in stateful.boxes {
                        if let previous = kept[path] {
                            fresh.adopt(from: previous)
                        }
                    }
                }

                // A state met for the first time is named by its property: the walk's paths spelled
                // once, for the new storages alone.
                // Design: docs/design/core/identity-and-diffing.md#a-path-is-a-number
                if stateful.boxes.contains(where: { !$0.box.isNamed }) {
                    let names = stateful.walk.names
                    for (path, box) in stateful.boxes where !box.isNamed { box.named(names[path] ?? "") }
                }

                // A state a scene keeps takes the scene's storage for its key, before the body
                // reads it (SceneRecord.swift).
                if let record = sceneRecord {
                    for (_, box) in stateful.boxes {
                        (box as? SceneClaiming)?.claimScene(record)
                    }
                }

                pass.views.append((
                    type: stateful.viewType, walk: stateful.walk, boxes: stateful.boxes, inputs: stateful.inputs,
                    branch: nil))

                // Slots resolve against everything provided so far, before the body builds.
                stateful.resolve(from: scope)

                // A composed view built with the same inputs that read nothing that moved is
                // carried whole; decided on the outermost view alone.
                // Design: docs/design/core/identity-and-diffing.md#carrying-a-view
                if step == 0 {
                    pass.seen = snapshot()

                    if let rendered = rendered, !forced, !describeAll, !stylesMoved, !buildsEveryView,
                        let kept = rendered.views.first,
                        kept.type == stateful.viewType,
                        rendered.reads.isDisjoint(with: changed),
                        rendered.seen == pass.seen,
                        let wrote = rendered.placeholder,
                        sameWriting(node, as: wrote),
                        Input.same(stateful.inputs, kept.inputs) {
                        if Inspection.recording {
                            pass.inspected = Inspection.enter(
                                stateful.viewType.name, .carried, element: id)
                        }

                        return carry(rendered, written: node)
                    }

                    if Inspection.recording {
                        pass.inspected = Inspection.enter(
                            stateful.viewType.name,
                            .built(reason(stateful, node: node, rendered: rendered, seen: pass.seen)),
                            element: id)
                    }
                }

                let built = BuildScope.Frame(
                    view: stateful.viewType.name,
                    builds: pass.builds,
                    read: rendered?.reads ?? [],
                    changed: self.changed,
                    written: self.written,
                    everything: describeAll,
                    element: id)

                pass.frame = built
                bodies.append(stateful.viewType.name)
                Renderer.shared.built += 1
                pass.entered += 1

                node = ReadScope.collect(into: &pass.reads) {
                    DerivationScope.collect(into: &pass.derived) {
                        BuildScope.within(built) { stateful.expand(over: node) }
                    }
                }
                pass.views[step].branch = node.branch
                pass.pushed += node.environments.count
                scope.append(contentsOf: node.environments)
                continue
            }

            break
        }

        // What the view says of its page: the page takes it where this is the view it shows, an arrangement standing
        // where a page stands its title and icon; anywhere else it says nothing.
        // Design: docs/design/views/pages.md#what-a-view-says-of-its-page
        pass.pageValues = node.pageValues
        node.pageValues = nil
        if let pageValues = pass.pageValues, !pass.atPageRoot {
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
        let within = pass.frame ?? bareFrame(for: rendered, builds: pass.builds, element: id)
        pass.within = within

        // A container built again for what its own closure read: an inspector names the
        // view and the container.
        if Inspection.recording, forced, pass.views.isEmpty {
            let owner = Inspection.short(within?.view ?? "a view")

            pass.inspected = Inspection.enter(
                "\(owner) › \(node.type.name)",
                .built("for " + names(of: (rendered?.reads ?? []).intersection(changed))),
                element: id)
        }

        let content = node
        pass.node = ReadScope.collect(into: &pass.reads) {
            let shallow = { () -> Node in
                var made = content
                made.materialize()
                return made
            }

            guard let within else { return shallow() }

            return DerivationScope.collect(into: &pass.derived) { BuildScope.within(within, shallow) }
        }
        return nil
    }

    /// A page describes the view it shows first, and says what that view says of it; it reads all that view's own
    /// build read, so a write the view's page values follow describes the page again.
    /// Design: docs/design/views/pages.md#what-a-view-says-of-its-page
    @inline(never)
    private func describePage(_ pass: ElementPass) {
        let rendered = pass.rendered
        let reshaped = rendered.map { $0.type != pass.node.type || !Self.sameKinds($0.views, pass.views) } ?? false
        var holder = HostPatch(id: pass.id, type: pass.node.type)
        describesPageRoot = true
        let children = reconcileChildren(
            of: reshaped ? nil : rendered, node: pass.node, into: &holder, sizesArrive: pass.node.childSizesArrive)
        describesPageRoot = false

        if let root = children.first {
            pass.reads.formUnion(root.reads)
            if let said = root.pageValues { pass.node.take(said) }
        }
        pass.described = (children, holder)
    }

    /// The element's own description compared with what it last said: its aim and readings, its style, visual states
    /// and themed values, its engines, whether it is replaced, and the patch of its properties, motion, watches,
    /// events and driven states - everything but its children.
    @inline(never)
    private func prepare(_ pass: ElementPass) {
        let (id, rendered, sizesArrive) = (pass.id, pass.rendered, pass.sizesArrive)
        var node = pass.node
        defer { pass.node = node }

        // An aim on the root of a composed view's content is the same element.
        if let inner = node.aim, inner !== pass.written {
            inner.attach(id, walk: walkStamp)
        }

        // The same for a reading written on that root.
        for (image, into, asks, take) in node.samples {
            pass.readings.append(image.sample(into: into, every: asks.window, take: take))
        }

        // The style is applied here, so a host receives every value already on the
        // control (StyleSheet.swift).
        node = styled(node, with: styles)

        // And its visual states resolved, the element reading what they follow.
        // Design: docs/design/views/styles.md#which-state-a-control-is-in
        let visualInput = node.visualStates.isEmpty ? nil : (rendered?.visualInput ?? VisualInput())
        var heard: [(index: Int, listener: VisualStateListener)] = []
        pass.visualInput = visualInput

        if let visualInput {
            (pass.visualState, heard) = resolveVisualStates(
                &node, input: visualInput, previous: rendered?.visualState, reads: &pass.reads)

            if pass.placeholder == nil {
                pass.placeholder = pass.authored
            }
        }

        // Themed values are picked here, which makes this element the theme's reader.
        // Design: docs/design/core/identity-and-diffing.md#themes
        if node.props.values.contains(where: \.isThemed) {
            let props = node.props
            node.props = ReadScope.collect(into: &pass.reads) {
                props.mapValues { $0.isThemed ? $0.resolvingTheme() : $0 }
            }

            if pass.placeholder == nil {
                pass.placeholder = pass.authored
            }
        }

        // The engines this element runs, under numbers it keeps; a conversion's engines
        // come first, in property order.
        // Design: docs/design/core/identity-and-diffing.md#engines-on-an-element
        let converting = node.driven.keys.sorted()
            .compactMap { node.driven[$0]!.conversion }
            .flatMap { $0.declarations() }

        // Properties described last render and not now are named for the host to clear.
        // Design: docs/design/core/identity-and-diffing.md#properties-no-longer-described
        let lost = (rendered?.props.keys.filter { node.props[$0] == nil } ?? []).sorted()

        // Except those with no host default, which replace the element - as a view of another kind does, a button
        // another kind of control makes (Node+ButtonMenu.swift), and another value a host makes its control by.
        // Design: docs/design/core/identity-and-diffing.md#another-kind-of-view
        let replace = rendered != nil
            && (rendered!.type != node.type || !Self.sameKinds(rendered!.views, pass.views)
                || lost.contains { !$0.facts.cleared } || rendered!.buttonMenuOpening != node.buttonMenuOpening
                || LibraryContracts.remaking.contains { rendered!.props[$0] != node.props[$0] })

        // Nothing to build on: the element is new, or cannot become what is described.
        let previous = replace ? nil : rendered
        pass.previous = previous

        // The runs of what this element's walks find, kept while it is the same element.
        let kept = replace ? RunSlots() : rendered?.runs ?? RunSlots()
        pass.kept = kept

        // A state entered is heard after this render; an element made again arrives in its state, unheard.
        if !replace, let state = pass.visualState {
            for (index, listener) in heard {
                fired.append(Fired(
                    run: { try await listener.handler.run(state) }, gate: listener.handler.gate,
                    owner: kept.owner("state \(index)")))
            }
        }

        if replace, let rendered = rendered {
            forget(rendered)
        }

        // Armed once the old element is let go: a replaced one starts its engines over under fresh numbers.
        pass.engines = arm(converting + node.engines, previous: previous?.engines)

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
                        run: { try await watch.run(old, new) }, gate: watch.gate,
                        owner: kept.owner("watch \(index)")))
                }
            }
        }

        // `.onCreated` for an element that was not here.
        // Design: docs/design/core/identity-and-diffing.md#created-and-destroying
        if previous == nil {
            for (index, created) in node.created.enumerated() {
                fired.append(Fired(run: created, owner: kept.owner("created \(index)")))
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

        #if DEBUG
        // A member the host's register says it does not realize on this element is said once.
        // Design: docs/design/core/contracts.md#unrealized-names
        for key in patch.properties.keys.sorted() {
            if let unhonoured = HostRealizations.unhonoured(key.key, on: node.type) { complain(unhonoured) }
        }
        #endif

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

        // A page listening for its disappearing hears its appearing too, so the core knows it stands shown.
        // Design: docs/design/host/pages.md#a-page-that-leaves-the-tree
        if node.type == .page, events[.disappearing] != nil, events[.appearing] == nil {
            let handlerId = previous?.events[.appearing] ?? allocateHandlerId()
            events[.appearing] = handlerId
            register([], under: handlerId)
        }
        if node.type == .page { keepPhases(of: id, events) }

        if let previous = previous {
            // An event this element no longer handles takes its id and its runs with it.
            for (name, handlerId) in previous.events.sorted(by: { $0.key < $1.key }) where events[name] == nil {
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
        pass.events = events

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

            state.inherited = mine
            state.answers[id] = mine
            answered.append((state, key))
            state.door = registration.kind
            state.laneKind = registration.laneKind

            driven[key] = StateEntry(
                number: Renderer.shared.number(for: state),
                mode: registration.mode,
                kind: registration.kind,
                laneKind: registration.laneKind)

            if previous?.driven[key]?.number != driven[key]!.number { state.ties += 1 }
        }

        // A tie this element no longer has is a channel fewer for its state, and an answer fewer.
        for (key, old) in previous?.driven ?? [:] where driven[key]?.number != old.number {
            untie(old.number, from: id)
        }

        let tiesChanged = describeAll || previous == nil
            ? !driven.isEmpty
            : driven != previous!.driven

        if tiesChanged {
            patch.driven = .replace(driven.mapValues(HostStateBinding.init))
        }
        pass.driven = driven
        pass.patch = patch
    }

    /// The element as it now stands, its children walked.
    @inline(never)
    private func finish(_ pass: ElementPass, children: [RenderedNode]) -> (node: RenderedNode, patch: HostPatch) {
        let node = pass.node
        let result = RenderedNode(
            id: pass.id,
            type: node.type,
            props: node.props,
            events: pass.events,
            motion: pass.patch.motion?.motion ?? pass.previous?.motion ?? .inherited,
            lanes: pass.patch.motion?.lanes ?? pass.previous?.lanes ?? .all,
            key: pass.key,
            views: pass.views,
            placeholder: pass.placeholder,
            view: pass.within?.view,
            reads: pass.reads,
            builds: pass.builds,
            provided: Array(scope.suffix(pass.pushed)),
            seen: pass.seen,
            watched: node.watches.map { $0.value },
            engines: pass.engines,
            driven: pass.driven,
            readings: pass.readings,
            derived: pass.derived,
            children: children
        )
        result.sizesArrive = pass.sizesArrive
        result.visualInput = pass.visualInput
        result.runs = pass.kept
        result.visualState = pass.visualState

        // What it says of the page it is the view of.
        result.pageValues = pass.atPageRoot ? pass.pageValues : nil

        // What it runs as it leaves: this build's closures, the newest.
        result.destroying = node.destroying

        return (result, pass.patch)
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

    /// Whether two elements are alike by their composed views: each one's type and the branch its content root
    /// stood in.
    /// Design: docs/design/core/identity-and-diffing.md#another-kind-of-view
    private static func sameKinds(_ one: [BuiltView], _ other: [BuiltView]) -> Bool {
        one.count == other.count && zip(one, other).allSatisfy { $0.type == $1.type && $0.branch == $1.branch }
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

        if buildsEveryView {
            return "a render asked for every view"
        }

        if rendered.seen != seen {
            return "an environment it sees was replaced"
        }

        if let wrote = rendered.placeholder, !sameWriting(node, as: wrote) {
            return "its parent wrote it differently"
        }

        if let input = Input.difference(stateful.inputs, kept.inputs, names: stateful.walk.names) {
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
        // Its body's handlers stand first and stay; only the ones the parent wrote last time are taken fresh.
        for (name, written) in node.events {
            if let id = rendered.events[name] {
                let wrote = rendered.placeholder?.events[name]?.count ?? 0
                let own = handlers[id].map { Array($0.handlers.dropLast(wrote)) } ?? []
                register(own + written, under: id)
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

/// One element as the walk reconciles it: what its steps hand on from one to the next, behind a reference, so the
/// walk's frame for the element holds a pointer rather than everything the steps work with.
/// Design: docs/design/core/identity-and-diffing.md#the-walks-stack
@MainActor
final class ElementPass {
    let id: ElementID
    let rendered: RenderedNode?
    let forced: Bool
    let sizesArrive: Bool

    /// Whether this is the view a page shows (PageValues.swift), and the scene the walk was in as it came.
    let atPageRoot: Bool
    let outerScene: SceneRecord?

    /// How many times this element has been described, this time included; the builder path, read before any
    /// placeholder is unwrapped; the aim written on it, attached to the key it settled on (Aim.swift).
    let builds: Int
    let key: PathNumber?
    let written: AimBox?

    /// The node as written, which a leaf wearing a themed value keeps; and as the steps make it.
    let authored: Node
    var node: Node

    /// What the element entered, left once it and its subtree are done: the environments it provided, the views it
    /// entered, and whether an inspector's frame is open for it (Inspection.swift).
    var pushed = 0
    var entered = 0
    var inspected = false

    /// The composed views unwrapped, outermost first, and the environments visible at the outermost, which a carry
    /// compares.
    /// Design: docs/design/core/identity-and-diffing.md#what-a-carry-cannot-see
    var views: [BuiltView] = []
    var seen: [ObjectIdentifier: ObjectIdentifier] = [:]

    /// What the clean walk needs to build this element again without its parent: a composed view keeps its
    /// placeholder, a container its node with the content still to run; a leaf keeps nothing.
    /// Design: docs/design/core/identity-and-diffing.md#the-clean-walk
    var placeholder: Node?

    /// The readings asked for here (Sampling.swift), everything the builds read, and the derived states they made
    /// or found.
    var readings: [Sampling] = []
    var reads: Set<ObjectIdentifier> = []
    var derived: [AnyObject] = []

    /// The frame the last body build ran under, and the one its container's content ran under.
    var frame: BuildScope.Frame?
    var within: BuildScope.Frame?

    /// What the view said of its page, and a page's own view described first.
    var pageValues: PageValues?
    var described: (children: [RenderedNode], patch: HostPatch)?

    /// What its comparison found: its visual states, its engines, what it continues, its runs, its handlers, its
    /// driven states and the patch.
    var visualInput: VisualInput?
    var visualState: KeyName?
    var engines: [Int] = []
    var previous: RenderedNode?
    var kept = RunSlots()
    var events: [Event: Int] = [:]
    var driven: [Prop: StateEntry] = [:]
    var patch: HostPatch

    init(
        id: ElementID, rendered: RenderedNode?, node: Node, forced: Bool, sizesArrive: Bool, atPageRoot: Bool,
        outerScene: SceneRecord?
    ) {
        self.id = id
        self.rendered = rendered
        self.forced = forced
        self.sizesArrive = sizesArrive
        self.atPageRoot = atPageRoot
        self.outerScene = outerScene
        builds = (rendered?.builds ?? 0) + 1
        key = node.key
        written = node.aim
        authored = node
        self.node = node
        placeholder = node.stateful != nil || node.producer != nil ? node : nil
        patch = HostPatch(id: id, type: node.type)
    }
}
