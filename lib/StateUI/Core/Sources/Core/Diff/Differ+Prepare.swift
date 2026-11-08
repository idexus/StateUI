// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

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
                kept = Renderer.shared.board.rearm(id, following: engine.follows, with: engine.run) && kept
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

            Renderer.shared.board.arm(EngineEntry(
                id: id,
                priority: engine.priority,
                follows: engine.follows,
                run: engine.run))

            return id
        }
    }
    /// The element's own description compared with what it last said: its aim and readings, its style, visual states
    /// and themed values, its engines, whether it is replaced, and the patch of its properties, motion, watches,
    /// events and driven states - everything but its children.
    @inline(never)
    func prepare(_ pass: ElementPass) {
        if let identity = pass.identity, [.menu, .menuItem, .menuToggle].contains(pass.node.type) {
            pass.menuKey = menuKeys.key(for: identity)
        }
        let (id, rendered, sizesArrive) = (pass.id, pass.rendered, pass.sizesArrive)
        var node = pass.node
        defer { pass.node = node }

        // An aim on the root of a composed view's content is the same element.
        if let inner = node.aim, inner !== pass.written {
            inner.attach(standing, walk: walkStamp)
        }
        if let declaration = node.declaration {
            pass.written?.declaration = declaration
            node.aim?.declaration = declaration
        }

        // The same for a reading written on that root.
        for (image, into, cadence, take) in node.samples {
            pass.readings.append(image.sample(into: into, every: cadence.window, take: take))
        }

        // What the element reads of a state it was handed - a picker's place, a tab, a stack's pages - read here, so
        // the element is that state's reader, never the body that wrote it.
        // Design: docs/design/core/invalidation.md#an-element-reads-what-it-was-handed
        if !node.describedReads.isEmpty {
            let reads = node.describedReads
            node.describedReads = []
            ReadScope.collect(into: &pass.ownReads) {
                for read in reads { read(&node) }
            }
            pass.reads.formUnion(pass.ownReads)

            if pass.placeholder == nil {
                pass.placeholder = pass.authored
            }
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
        // come first, in property order, each chain from its first sources, each conversion once.
        // Design: docs/design/core/identity-and-diffing.md#engines-on-an-element
        var convertedOnce = Set<ObjectIdentifier>()
        let converting = node.driven.keys.sorted()
            .compactMap { node.driven[$0]!.conversion }
            .flatMap(\.chain)
            .filter { convertedOnce.insert(ObjectIdentifier($0)).inserted }
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
        let watchKeys = node.watches.enumerated().map {
            RunSlots.Key.watch($0.offset, ObjectIdentifier(type(of: $0.element.value)))
        }
        let stateKeys = node.visualStateListeners.enumerated().map {
            RunSlots.Key.visualState($0.offset, $0.element.states)
        }
        kept.keep(Set(watchKeys + stateKeys + node.created.indices.map { .created($0) }))

        // A state entered is heard after this render; an element made again arrives in its state, unheard.
        if !replace, let state = pass.visualState {
            for (index, listener) in heard {
                fired.append(Fired(
                    run: { try await listener.handler.run(state) }, gate: listener.handler.gate,
                    owner: kept.owner(.visualState(index, listener.states))))
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
                : (plan?.motion(for: .place) ?? .inherited)

            // Inherited until told otherwise; the application says its own once.
            let was: Motion? = node.type == .application
                ? (describeAll ? nil : previous?.motion)
                : (describeAll ? .inherited : (previous?.motion ?? .inherited))

            // Which parts of a child's place animate.
            var lanes = MotionLanes.all

            if travel(.place).kind == .none { lanes.subtract(.place) }
            if travel(.width).kind == .none { lanes.subtract(.width) }
            if travel(.height).kind == .none { lanes.subtract(.height) }

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
        var pairs: [(index: Int, old: Any)] = []
        if let previous = previous, previous.watched.count == node.watches.count {
            pairs = previous.watched.enumerated().map { ($0.offset, $0.element) }
        }
        for (index, old) in pairs {
            let watch = node.watches[index]

            // Nil: the stored value is of another type, and the slot starts over.
            if watch.matches(old) == false {
                let new = watch.value
                fired.append(Fired(
                    run: { try await watch.run(old, new) }, gate: watch.gate,
                    owner: kept.owner(.watch(index, ObjectIdentifier(type(of: watch.value))))))
            }
        }

        // The events of the application's it hears, subscribed while it stands.
        kept.listen(to: node.hostEvents)

        // `.onCreated` for an element that was not here.
        // Design: docs/design/core/identity-and-diffing.md#created-and-destroying
        if previous == nil {
            for (index, created) in node.created.enumerated() {
                fired.append(Fired(run: created, owner: kept.owner(.created(index))))
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
        // A member the host's register says it does not realize on this element is said once - not one the library
        // wrote itself, its author having said nothing, nor a mark only the library writes.
        // Design: docs/design/core/contracts.md#unrealized-names
        for key in patch.properties.keys.sorted()
        where patch.properties[key] != key.facts.unsaid && !key.facts.writtenByStateUI {
            if let unhonored = HostRealizations.unhonored(key.key, on: node.type) { complain(unhonored) }
        }
        #endif

        // A property that changed on a continuing element animates to its new value; a
        // measured size arrives at once.
        // Design: docs/design/core/identity-and-diffing.md#transitions
        let measured = sizesArrive || node.reportsFrame

        if !describeAll, !replace, previous != nil, plan != nil || travels.kind != .none {
            // A value taken away travels by the value it was, back to where its host rests it.
            let taken = patch.clearedProperties.compactMap { property in rendered?.props[property].map { (property, $0) } }
            for (property, value) in patch.properties.map({ ($0.key, $0.value) }) + taken
            where value.moves && property.facts.travels
                && patch.transitions[property] == nil {
                if measured, !property.facts.moves.isDisjoint(with: [.width, .height]) { continue }

                let moves = travel(value.kind.union(property.facts.moves))

                if moves.kind == .none { continue }

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
}
