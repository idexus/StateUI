// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// One element reconciled: its composed views carried or built, its properties,
// events, engines and driven states compared, and the patch that says so.
// Design: docs/design/core/identity-and-diffing.md#carrying-a-view

extension Differ {

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
        sizesArrive: Bool = false,
        atPagePosition: Bool? = nil,
        from start: Int = 0
    ) -> (node: RenderedNode, patch: HostPatch) {
        let pass = ElementPass(
            id: id, rendered: rendered, node: node, forced: forced, sizesArrive: sizesArrive,
            atPageRoot: describesPageRoot, atPagePosition: atPagePosition ?? describesPagePosition,
            outerScene: sceneRecord, start: start)
        (describesPageRoot, describesPagePosition) = (false, false)
        standing.append(id)

        // What the element entered - the environments provided, the views, its scene, an inspector's frame - is
        // left once it and its subtree are done.
        defer {
            standing.removeLast()
            sceneRecord = pass.outerScene
            bodies.removeLast(pass.entered)
            scope.removeLast(pass.pushed)
            if pass.enablement != nil { enablements.removeLast() }
            if pass.inspected { Inspection.leave() }
        }

        if let carried = expand(pass) { return carried }
        if pass.node.type == .page { describePage(pass) }
        prepare(pass)

        // What it says of its enablement holds for everything in it.
        pass.enablement = Enablement(pass.node)
        if let enablement = pass.enablement { enablements.append(enablement) }

        let children: [RenderedNode]
        if let described = pass.described {
            children = described.children
            pass.patch.children = described.patch.children
        } else {
            // An anchor at a page's root is no view of the page: the view it holds is.
            // Design: docs/design/core/identity-and-diffing.md#a-views-anchor
            describesPageRoot = pass.atPageRoot && pass.node.type == .anchor
            children = reconcileChildren(
                of: pass.previous, node: pass.node, into: &pass.patch, sizesArrive: pass.node.childSizesArrive,
                atPagePosition: pass.atPagePosition)
            describesPageRoot = false
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

        // An aim takes where this element stands (Aim.swift).
        pass.written?.attach(standing, walk: walkStamp)

        // The readings asked for here, keyed by their target and held by this element
        // (Sampling.swift).
        for (image, into, cadence, take) in node.samples {
            pass.readings.append(image.sample(into: into, every: cadence.window, take: take))
        }

        // What `.environment()` provided here joins the scope before anything below
        // resolves; the count is kept for the clean walk.
        pass.pushed = node.environments.count
        scope.append(contentsOf: node.environments)

        if pass.start > 0, let rendered { node = standOutside(pass, rendered, through: pass.start) }

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

                // One value standing in two places under different providers would read one of them from both:
                // the second place shows nothing, said once. After the walk is taken, so a view built as it was
                // is walked by no mirror for this.
                // Design: docs/design/core/identity-and-diffing.md#one-value-in-two-places
                let slots = resolution(of: stateful)
                guard place(slots, at: id) else {
                    complain(refusal(of: stateful))
                    pass.refused = true
                    node = Node(contract: AnchorContract.self)
                    break
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
                    slots: slots, branch: nil, placeholder: node, reads: [], derived: []))

                // Slots resolve against everything provided so far, before the body builds.
                stateful.resolve(from: scope)

                // A composed view built with the same inputs that read nothing that moved is
                // carried whole; decided on the outermost view alone.
                // Design: docs/design/core/identity-and-diffing.md#carrying-a-view
                if step == 0 {
                    pass.seen = snapshot()
                    pass.branch = enablements.compactMap(\.key)

                    if let rendered = rendered, !forced, !describeAll, !stylesMoved, !buildsEveryView,
                        let kept = rendered.views.first,
                        kept.type == stateful.viewType,
                        rendered.seen == pass.seen,
                        rendered.branch == pass.branch,
                        let wrote = rendered.placeholder,
                        sameWriting(node, as: wrote),
                        Input.same(stateful.inputs, kept.inputs) {
                        if rendered.reads.isDisjoint(with: changed) {
                            if Inspection.recording {
                                pass.inspected = Inspection.enter(
                                    stateful.viewType.name, .carried, element: id)
                            }

                            return carry(rendered, written: node)
                        }

                        // What moved was read by a view inside alone: the walk goes on from it.
                        let start = Self.start(of: rendered, changed: changed)
                        if start > 0 {
                            node = standOutside(pass, rendered, through: start)
                            continue
                        }
                    }
                }
                if step == pass.builtFrom, Inspection.recording {
                    pass.inspected = Inspection.enter(
                        stateful.viewType.name,
                        .built(reason(stateful, node: node, rendered: rendered, seen: pass.seen)),
                        element: id)
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

                var read: Set<ObjectIdentifier> = []
                var made: [AnyObject] = []
                node = ReadScope.collect(into: &read) {
                    DerivationScope.collect(into: &made) {
                        BuildScope.within(built) { stateful.expand(over: node) }
                    }
                }
                pass.reads.formUnion(read)
                pass.derived += made
                pass.views[step].branch = node.branch
                pass.views[step].reads = read
                pass.views[step].derived = made
                pass.pushed += node.environments.count
                scope.append(contentsOf: node.environments)
                continue
            }

            break
        }

        // An element under composed views that reads a state itself is described again from here alone.
        if !pass.views.isEmpty, !node.describedReads.isEmpty {
            pass.expanded = node
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
            sceneRecord = OpenScenes.shared.record(key: name)
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

    /// What each `@Environment` slot of `stateful` resolves to where the walk stands.
    private func resolution(of stateful: Node.Stateful) -> [PlacedSlot] {
        stateful.slots.map { slot in
            (ObjectIdentifier(slot), scope.last { $0.key == slot.wants }.map { ObjectIdentifier($0.object) })
        }
    }

    /// Marks `slots` as standing at `id` this walk, with what each resolved to, or places none: one of them stood
    /// this walk at another element the walk is not inside - so no holder of the view - resolving to another object.
    /// Design: docs/design/core/identity-and-diffing.md#one-value-in-two-places
    private func place(_ slots: [PlacedSlot], at id: ElementID) -> Bool {
        for (slot, object) in slots {
            if let earlier = placed[slot], earlier.element != id, !standing.contains(earlier.element),
                earlier.object != object {
                return false
            }
        }

        for (slot, object) in slots {
            placed[slot] = (id, object)
        }

        return true
    }

    /// Places the slots of `views`, standing as they were built, in order up to one the placing refuses: how many
    /// stand.
    func stand(_ views: ArraySlice<BuiltView>, at id: ElementID) -> Int {
        for (step, view) in views.enumerated() where !place(view.slots, at: id) {
            return step
        }

        return views.count
    }

    /// What the library says of a value refused its second place.
    private func refusal(of stateful: Node.Stateful) -> String {
        let name = Inspection.short(stateful.viewType.name)
        return "A \(name) value stands in two places under different environments, so the second shows "
            + "nothing: its @Environment belongs to the place it stands in. Make a value for each place - "
            + "write \(name)() where each stands."
    }

    /// Which of `rendered`'s views a walk for `changed` builds from: the outermost whose own body read what moved; the
    /// innermost, where none did - the content a container runs, the values it wears.
    /// Design: docs/design/core/identity-and-diffing.md#the-clean-walk
    static func start(of rendered: RenderedNode, changed: Set<ObjectIdentifier>) -> Int {
        if let read = rendered.views.firstIndex(where: { !$0.reads.isDisjoint(with: changed) }) { return read }

        // Only the element read what moved: the walk goes on from the element its views made.
        return rendered.expanded != nil ? rendered.views.count : max(rendered.views.count - 1, 0)
    }

    /// The views of `rendered` outside its view `asked` standing as they were built - their state, their slots as
    /// placed, what they read and made, the environments they provided: the node the walk goes on from, the one
    /// holding that view - or holding the first view whose slots the placing refuses, which the walk refuses.
    /// Design: docs/design/core/identity-and-diffing.md#the-clean-walk
    private func standOutside(_ pass: ElementPass, _ rendered: RenderedNode, through asked: Int) -> Node {
        let start = stand(rendered.views.prefix(asked), at: pass.id)
        pass.views = Array(rendered.views.prefix(start))
        pass.seen = rendered.seen
        pass.builtFrom = start
        for view in pass.views {
            pass.reads.formUnion(view.reads)
            pass.derived += view.derived
            if let record = view.placeholder.stateful?.scene, sceneRecord == nil { sceneRecord = record }
        }
        // The nodes standing from the outermost view in, the starting one included - the element itself, where the
        // walk starts there.
        let element = start == rendered.views.count ? rendered.expanded : nil
        let standing = rendered.views.dropFirst().prefix(start).map(\.placeholder) + (element.map { [$0] } ?? [])
        for node in standing {
            pass.pushed += node.environments.count
            scope.append(contentsOf: node.environments)
        }
        return element ?? rendered.views[start].placeholder
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
            // Not what the view's element read for itself: no page value follows that.
            let built = root.views.reduce(into: Set<ObjectIdentifier>()) { $0.formUnion($1.reads) }
            pass.reads.formUnion(root.reads.subtracting(root.ownReads).union(built))
            if let said = root.pageValues { pass.node.take(said) }
        }
        pass.described = (children, holder)
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
    static func sameKinds(_ one: [BuiltView], _ other: [BuiltView]) -> Bool {
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
            node.hostEvents.count == kept.hostEvents.count,
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
    func register(_ written: [Handler], under id: Int) {
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

        // Its `.onDestroying`: its body's last ones, then the parent's, taken fresh; its events' handlers alike.
        rendered.destroying =
            Array(rendered.destroying.dropLast(node.destroying.count)) + node.destroying
        rendered.hostEvents = Array(rendered.hostEvents.dropLast(node.hostEvents.count)) + node.hostEvents
        rendered.runs.listen(to: rendered.hostEvents)

        rendered.placeholder = node

        return revisit(rendered, walking: false, standingAlready: true)
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
