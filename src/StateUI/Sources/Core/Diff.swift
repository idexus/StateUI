// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Turning "here is the tree" into "here is what changed".
//
// The author's closure runs in full on every render and produces a complete tree
// of Nodes - that is what makes state updates work without any invalidation by
// hand. What goes over the wire is a different question, and this file answers
// it: the new tree is walked against the one C# is already showing, and only the
// differences are packed into a Patch.
//
// Two things are allocated here and nowhere else, because both have to outlive
// the tree that introduced them:
//
//   element ids   what C# matches a control by. An element keeps its id, and
//                 therefore its control, for as long as it stays in the tree.
//   handler ids   what C# quotes back when an event fires. Kept for as long as
//                 the element handles that event, so a control that is not part
//                 of a message goes on using the id it already has.
//
// The closures themselves are registered afresh whenever an element is BUILT,
// changed or not: a button whose caption did not change can still have captured
// a different value this time round. An element a walk carries over - a memo
// whose token is unchanged, a view none of whose state moved - keeps the
// closures it last registered, and they are current for the same reason the
// carry is sound: nobody computed newer values for them to have captured.

/// Walks the authored tree against the rendered one and produces the message.
final class Differ {
    /// Never reset, not even by a resync: an id that has been used is never
    /// handed out again, so a stale control on the C# side can never be mistaken
    /// for a new one that happens to land on the same number.
    private var nextElementId = 1

    /// The same rule for handler ids, and for the same reason: an event arriving
    /// late must never reach the wrong closure.
    private var nextHandlerId = 1

    /// Which walk this is, counted at every entry - what a `ControlBox` uses
    /// to tell a second attach in the SAME walk (one control state on two
    /// views, a conflict the act reports) from the next walk attaching it
    /// afresh.
    private var walkStamp = 0

    /// Whether the current walk describes every element in full rather than
    /// only what changed. Set by `reconcile` for a resync - a host that is not
    /// holding the current generation - and read by every decision below about
    /// what goes INTO the patch. What it deliberately does not change is the
    /// matching: identities, state adoption and handler bookkeeping work
    /// exactly as in an ordinary diff, or a resync would reset every `@State`
    /// and leak the whole registry.
    private var describeAll = false

    /// The styles every element this walk builds is resolved against - the
    /// application's sheet, as it stood when the tree was built.
    ///
    /// Kept between walks because a clean walk (`revisit`) does not build the
    /// window and therefore never reads it: what it carries over was resolved
    /// against this same sheet. See Views/Style.swift.
    private var styles: StyleSheet?

    /// How a value that CHANGED travels, where its element says nothing else -
    /// the application's own answer, read once at the top of every walk.
    ///
    /// Set by `Renderer.renderWire` beside the styles and left at this library's
    /// own default everywhere else, which is what makes a differ built by a test
    /// describe the motions an application would see.
    var motion: Motion = .standard

    /// Whether the sheet MOVED at the top of this walk.
    ///
    /// The one thing a memoized subtree cannot see: its token says the inputs
    /// have not changed, and a style is not one of them - so a sheet that
    /// replaced a value under an unchanged token would leave the old one on
    /// screen for ever. The skip is suppressed for that one walk, exactly as
    /// `seen` suppresses it for a provider that replaced its object.
    private var stylesMoved = false

    /// The state that has changed since the tree C# is showing was built, by
    /// storage identity - what the renderer collected from `stateChanged`.
    ///
    /// Read in two places, and they are the same decision: `revisit`, deciding
    /// whether a kept element must be built again, and the memo skip below,
    /// which WALKS a skipped subtree rather than carrying it - a token says
    /// the INPUTS are unchanged, and state a body reads is not an input.
    private var changed: Set<ObjectIdentifier> = []

    /// What each changed state is CALLED, by storage identity - the author's
    /// own property names, for `debugInfo()` to explain a build with. Set by
    /// `Renderer.renderWire` beside the flights, and empty everywhere else.
    /// See Core/Builds.swift.
    var named: [ObjectIdentifier: String] = [:]

    /// The flights this walk may carry - the renderer's book, taken once
    /// before the walk so that asking about one costs no lock.
    ///
    /// Set by `Renderer.renderWire` and left empty everywhere else, which is
    /// what makes a differ built by a test emit no transitions at all.
    var flights: [FlightKey: PendingFlight] = [:]

    /// The states written with `snap(to:)` since the last render - whose
    /// properties travel no distance at all this time round.
    var snapping: Set<FlightKey> = []

    /// The flights this walk actually wrote a transition for. What is not in
    /// here when the message is packed had nothing to fly and is answered on
    /// the spot - see `Renderer.settle`.
    private var carried: Set<FlightKey> = []

    /// The handlers this walk found something to run - an `.onChanged` whose
    /// value moved, an `.onUnloaded` whose element left - in the order they
    /// were reached.
    ///
    /// Collected rather than run: a handler may write `@State`, and a write
    /// landing mid-render is cleared by the bookkeeping that ends it. The
    /// renderer takes these once the message is packed and runs them then. See
    /// Core/Changes.swift.
    private var fired: [EventHandler] = []

    /// The environments in scope where the walk currently stands - what
    /// `.environment()` provided on this element's ancestors, nearest LAST.
    /// Pushed as elements are entered and popped as they are left, in both
    /// walks; a `@Environment` slot resolves against it just before the
    /// view's body builds. See Core/Environment.swift.
    private var scope: [(key: ObjectIdentifier, object: AnyObject)] = []

    /// Every live `unloaded` handler id, and whether the HOST has already run
    /// it - which is what keeps a view from being told twice that it has gone.
    ///
    /// A platform back is exactly that order: MAUI pops the page and unloads
    /// its views while the element is still described, and the truncated path
    /// reaches this walk one render later, by which time the view has been
    /// told. Going the other way - a page left by an assignment - the element
    /// goes first and the host's own event finds nobody, which is what `forget`
    /// answers instead. Marked here, whichever of the two comes second says
    /// nothing.
    ///
    /// An entry goes back to false when the host reports the view LOADED
    /// again, and only then: a walk is no evidence either way, since a view the
    /// platform has unloaded goes on being described for as long as something
    /// covers it. See `loads`.
    private var unloads: [Int: Bool] = [:]

    /// Each live `loaded` handler id against the `unloaded` one beside it -
    /// what a load reaches to say that the view is showing again.
    private var loads: [Int: Int] = [:]

    /// What every live element's events run.
    ///
    /// Kept BETWEEN renders rather than rebuilt by each one. A memoized subtree
    /// is not walked while its inputs are unchanged, so there is nothing to
    /// re-register it with - and its handlers have to go on working. Entries are
    /// overwritten as elements are visited and dropped when an element leaves
    /// the tree, which is what `forget` is for.
    private var handlers: [Int: EventHandler] = [:]

    /// Reconciles the tree just written against the one C# is showing.
    ///
    /// `describeAll` makes the patch carry every element in full - for a host
    /// that has lost track of the tree and needs the whole thing - while the
    /// walk still matches against `rendered`, so element ids, handler ids and
    /// `@State` survive a resync the way they survive any other render. Passing
    /// `nil` for `rendered` instead is only for a first render, when there is
    /// nothing to carry over.
    func reconcile(
        _ rendered: RenderedNode?,
        with tree: Node,
        styles: StyleSheet? = nil,
        describeAll: Bool = false,
        changed: Set<ObjectIdentifier> = []
    ) -> (node: RenderedNode, patch: Patch) {
        self.describeAll = describeAll
        self.changed = changed
        stylesMoved = !StyleSheet.same(styles, self.styles)
        self.styles = styles
        walkStamp += 1
        seedScope()

        // The root has no siblings to be told apart from, so it keeps whatever
        // identity it was given until the author states another one.
        let id = tree.id.map(ElementId.manual) ?? rendered?.id ?? identity(for: tree)
        let previous = rendered?.id == id ? rendered : nil

        if let rendered = rendered, previous == nil {
            forget(rendered)
        }

        return element(id: id, rendered: previous, node: tree)
    }

    /// Walks the tree C# is showing with NO fresh tree to compare against, and
    /// rebuilds exactly the elements whose recorded reads intersect `changed`.
    ///
    /// This is the render that skips the author's closure: nothing above a
    /// changed view is built, walked or sent - the ancestors contribute only
    /// the path of carrier patches down to it. It is only sound when every
    /// cause of the render named the state it wrote; anything else goes
    /// through `reconcile` with a freshly built tree. See
    /// Core/Invalidation.swift for the two facts this rests on.
    func revisit(
        _ rendered: RenderedNode,
        changed: Set<ObjectIdentifier>
    ) -> (node: RenderedNode, patch: Patch) {
        describeAll = false
        self.changed = changed
        stylesMoved = false
        walkStamp += 1
        seedScope()

        return revisit(rendered)
    }

    /// One kept element: built again from what it kept when its reads moved,
    /// walked for changed descendants when they did not.
    ///
    /// The rebuild runs the closure the element's placeholder captured LAST
    /// render - which is correct precisely because this walk got here: the
    /// parent was left alone, so nobody computed newer inputs than the ones
    /// that closure holds. A parent that IS rebuilt writes fresh placeholders
    /// for its children, and those are built by `element`, never here. A clean
    /// walk moves nothing either: a child's place among its siblings is its
    /// parent's business, and this walk only runs where the parent was left
    /// alone.
    private func revisit(
        _ rendered: RenderedNode
    ) -> (node: RenderedNode, patch: Patch) {
        // A MEMO IS GOVERNED BY ITS TOKEN AND NOTHING ELSE, so the walk
        // stops here and carries the subtree whole - not one element under it
        // is asked whether the state it read has moved.
        //
        // What the content read while it ran is not one of the inputs the
        // token names, and rebuilding for it would re-run the very closure
        // the token was written to prevent: a subtree big enough to be worth
        // memoizing almost always touches state somewhere, so a memo that
        // yielded to reads would save nothing in practice. The author said
        // this content is the same while the token holds, and the library
        // takes them at their word - which is what makes the word mean
        // something.
        //
        // The token can still move: that happens where the PARENT is
        // rebuilt, which puts a fresh node here and takes the whole
        // comparison through `element` again.
        if rendered.memo != nil {
            return (rendered, Patch(id: rendered.id, type: rendered.type))
        }

        if let placeholder = rendered.placeholder,
            !rendered.reads.isDisjoint(with: changed) {
            return element(
                id: rendered.id,
                rendered: rendered,
                node: placeholder,
                forced: true)
        }

        var patch = Patch(id: rendered.id, type: rendered.type)

        // What this element provided stays in scope while its children are
        // walked, so a view rebuilt deep under clean ancestors resolves its
        // `@Environment` exactly as a full build would.
        scope.append(contentsOf: rendered.provided)
        defer { scope.removeLast(rendered.provided.count) }

        for (index, child) in rendered.children.enumerated() {
            let (node, childPatch) = revisit(child)
            rendered.children[index] = node

            if !childPatch.isEmpty {
                patch.children.append(childPatch)
            }
        }

        return (rendered, patch)
    }

    /// What an element's event runs, or nothing if the id is unknown.
    ///
    /// Asked for because it is about to run, which is why an `unloaded` is
    /// written down here: the host has answered it, so the element leaving the
    /// tree later must not answer it again. See `unloads`.
    func handler(_ id: Int) -> EventHandler? {
        guard let handler = handlers[id] else { return nil }

        if unloads[id] != nil {
            unloads[id] = true
        } else if let unloaded = loads[id] {
            unloads[unloaded] = false
        }

        return handler
    }

    /// The `.onChanged` handlers the last walk found a change for, and forgets
    /// them.
    ///
    /// Taken rather than read so that a handler runs once for the change that
    /// produced it. The renderer calls this after the message is built - see
    /// Core/Changes.swift for why not before.
    func takeFired() -> [EventHandler] {
        let taken = fired
        fired.removeAll(keepingCapacity: true)
        return taken
    }

    /// The flights this walk wrote a transition for, and forgets them.
    func takeCarried() -> Set<FlightKey> {
        let taken = carried
        carried.removeAll(keepingCapacity: true)
        return taken
    }

    /// Drops the handlers of an element that has left the tree, and of
    /// everything under it - running its `.onUnloaded` on the way out.
    ///
    /// That handler is answered HERE and not from the host, because an element
    /// leaves the tree BEFORE the control does: the host is told to take the
    /// view down by the very message this walk is packing, so MAUI's own
    /// `Unloaded` arrives against a handler id nothing knows any more and is
    /// heard by nobody. Which is what left a page that navigation ASSIGNED its
    /// way out of - the path emptied, the page still on screen for the length
    /// of a transition - never told that it had gone.
    ///
    /// The host's event still answers the other half: a view unloaded while its
    /// element STAYS in the tree - a page pushed over, a tab switched away
    /// from - is the platform's to report, and it does.
    private func forget(_ node: RenderedNode) {
        if let id = node.events[.unloaded], unloads.removeValue(forKey: id) != true,
           let handler = handlers[id] {
            fired.append(handler)
        }

        if let id = node.events[.loaded] {
            loads.removeValue(forKey: id)
        }

        for id in node.events.values {
            handlers.removeValue(forKey: id)
        }

        // And the arithmetic it ran between renders, which nothing is left to
        // ask for: an engine whose view has gone would go on being handed
        // frames for a picture nobody can see.
        for id in node.engines {
            Renderer.shared.disarm(id)
        }

        for child in node.children {
            forget(child)
        }
    }

    // MARK: - One element

    /// Registers this element's engines, or hands the ones it already has the
    /// arithmetic this render wrote.
    ///
    /// - Parameters:
    ///   - declared: what the tree says it runs.
    ///   - previous: the numbers it ran under last render.
    ///   - named: what to call the view in a complaint about one of them.
    /// - Returns: the numbers it runs under now.
    private func arm(
        _ declared: [EngineDeclaration],
        previous: [Int]?,
        named: String?
    ) -> [Int] {
        if let previous = previous, previous.count == declared.count {
            var kept = true

            for (id, engine) in zip(previous, declared) {
                kept = Renderer.shared.board(for: engine.sync).rearm(id, with: engine.run) && kept
            }

            // Unless the board has forgotten them - which is what a resync
            // after a session was claimed afresh looks like - and then they are
            // registered again under the numbers they already had.
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
                follows: engine.follows.map { $0.held },
                origin: named,
                run: engine.run))

            return id
        }
    }

    /// Reconciles one element against what C# has for it, and returns both the
    /// element as it now stands and the patch that gets C# there.
    ///
    /// The four cases, in the order they are decided: a memoized subtree whose
    /// token has not moved (nothing is built at all), an element that cannot be
    /// patched into shape (replaced whole), an element that changed (its
    /// properties, events and children), and one that did not (an empty patch
    /// its parent drops).
    private func element(
        id: ElementId,
        rendered: RenderedNode?,
        node: Node,
        forced: Bool = false
    ) -> (node: RenderedNode, patch: Patch) {
        var node = node
        var memo: AnyHashable?
        var views: [(type: String, boxes: [(path: String, box: StateBox)])] = []

        // How many times this element has been described, this time included -
        // one integer carried along the element, which is what lets a view ask
        // how often it is being rebuilt. See Core/Builds.swift.
        let builds = (rendered?.builds ?? 0) + 1

        // Read from what the AUTHOR wrote, before any stand-in is unwrapped: the
        // path belongs to where the element was written, and the subtree a memo
        // or a composed view produces was written somewhere else entirely.
        let key = node.key

        // A control state assigned to the view takes the identity this element
        // settled on - which is the whole of how an act aims, so it happens
        // before anything else can return. See Core/ControlState.swift.
        let written = node.assigned
        written?.attach(id, walk: walkStamp)

        // What `.environment()` provided HERE joins the scope before anything
        // below can resolve - the view's own slots included, since an object
        // provided on the view is the view's to read. Pushed as stand-ins
        // unwrap (their content roots may provide too), popped however this
        // element returns. The total is recorded on the element, so the clean
        // walk can push the same scope without building anything.
        var pushed = node.environments.count
        scope.append(contentsOf: node.environments)
        defer { scope.removeLast(pushed) }

        // The environments visible at this element's memo, when it has one -
        // what the skip compares beside the token. See Core/Environment.swift.
        var seen: [ObjectIdentifier: ObjectIdentifier] = [:]

        // Kept on the element it builds, so a later render can build the
        // subtree again without the parent having written it - which is what
        // `revisit` does. A plain node stands in for nothing and keeps
        // nothing: its properties were computed by an ancestor's build, and a
        // change to them starts at that ancestor's own placeholder.
        let placeholder = node.stateful != nil || node.memo != nil ? node : nil

        // Everything the builds below read, recorded against this element -
        // the other half of what `revisit` decides by.
        var reads: Set<ObjectIdentifier> = []

        // Unwraps what stands in for a subtree, outermost first, until a real
        // node comes out. A loop because the stand-ins nest: a memoized
        // composed view is a memo around a placeholder, a composed view made of
        // another is a placeholder around a placeholder.
        while true {
            // A memoized view: worth building only if what it was built from
            // has changed. See Core/Memo.swift.
            if let promise = node.memo {
                memo = promise.token
                seen = snapshot()

                // Not when everything is being described: the skip's whole
                // saving is sending nothing, and a resync must send it all.
                // Not when this element was sent here BY the walk either -
                // the token being unchanged is what the walk already knows,
                // and honouring it would skip the very build it came for.
                // And not when a provider above REPLACED an object the token
                // cannot see - the environments are compared beside it - nor
                // when the STYLES moved, which a token cannot see either.
                if let rendered = rendered, !forced, !describeAll, !stylesMoved,
                    rendered.memo == promise.token, rendered.seen == seen {
                    // The inputs are unchanged, so nothing here is built - but
                    // an unchanged token says nothing about the state a body
                    // READS, so the subtree is WALKED rather than carried
                    // blindly: clean parts carry over with their identities,
                    // state and handlers, and a view whose state moved is
                    // built again from what its element kept.
                    return revisit(rendered)
                }

                node = ReadScope.collect(into: &reads) { promise.build() }
                pushed += node.environments.count
                scope.append(contentsOf: node.environments)
                continue
            }

            // A composed view: the same identity holding the same KIND of view
            // keeps its state, so the fresh boxes adopt their predecessors'
            // storage BEFORE the body is built and reads them. A different view
            // type at this position starts over, exactly as a different control
            // type replaces the control. See Core/Stateful.swift.
            if let stateful = node.stateful {
                let step = views.count

                if let rendered = rendered,
                    step < rendered.views.count,
                    rendered.views[step].type == stateful.viewType {
                    // By PATH, not by position: a view may store another view,
                    // and a stored slot that fills between two renders would
                    // shift every box declared after it by one - handing a
                    // counter that was never touched the count of one that
                    // was. A path nobody answered is a box that starts at its
                    // initial value, which is what a newly stored view's state
                    // is.
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

                views.append((type: stateful.viewType, boxes: stateful.boxes))

                // The `@Environment` slots resolve against everything provided
                // so far - the view's own `.environment()` included - BEFORE
                // the body builds and its handlers capture the view.
                stateful.resolve(from: scope)

                node = ReadScope.collect(into: &reads) {
                    BuildScope.within(
                        BuildScope.Frame(
                            view: stateful.viewType,
                            builds: builds,
                            read: rendered?.reads ?? [],
                            changed: self.changed,
                            names: self.named,
                            everything: describeAll)
                    ) { stateful.expand(over: node) }
                }
                pushed += node.environments.count
                scope.append(contentsOf: node.environments)
                continue
            }

            break
        }

        // THE CONTAINER'S CONTENT RUNS HERE, inside the same read scope the
        // body build used - so everything the author's closure reads lands on
        // this element, exactly as it did when a container built its children
        // in its own initializer. Deep, down to the next placeholder, because
        // a nested bare container's element has no placeholder of its own to
        // be rebuilt from: its content's reads must belong to the element the
        // clean walk CAN rebuild, which is this one.
        //
        // After the unwrap loop, so a memoized subtree whose token held has
        // already returned above and its content never runs - which is the
        // whole saving - and before `styled`, which may need the children to
        // append a style's visual states after them.
        //
        // ALWAYS INSIDE THE SCOPE, and never on the strength of THIS node
        // carrying a producer: the deferred content can sit anywhere in the
        // descent, and a body whose root is built directly is the shape where
        // it always does - a page's node is its properties, its content and
        // its slots, so the container the author wrote is a CHILD of the node
        // the unwrapping ends on. The reads are this element's wherever they
        // are made, that being the one whose placeholder can build them again.
        node = ReadScope.collect(into: &reads) {
            var made = node
            made.materializeDeep()
            return made
        }

        // The content a composed view unwrapped to may carry an assignment of
        // its own on its root - the SAME element, so it takes the same
        // identity. This is what a string id inside a composed view can never
        // have: the identity is fixed on the placeholder before the content
        // exists, and only this walk knows the two are one.
        if let inner = node.assigned, inner !== written {
            inner.attach(id, walk: walkStamp)
        }

        // The style, applied HERE and nowhere else: what the host receives is a
        // control with every value already on it, so nothing on the far side
        // has to know what a style is. After the unwrapping, because it is the
        // real node's type and key that decide which style it wears; before
        // everything below, because from here on this node is what is sent.
        // See Views/Style.swift.
        node = styled(node, with: styles)

        // The arithmetic this element runs on the host's own frames, if it
        // has any: registered under ids the element KEEPS, so a render hands
        // the newest closure - this render's captures - to the engine that
        // already has a number, rather than starting one over. A different
        // COUNT is a different SET, the reading a changed number of watches
        // gets and for the same reason: an `.engine` written under an `if`
        // moves every one after it. See Core/Cycle.swift.
        let engines = arm(node.engines, previous: rendered?.engines, named: views.first?.type)

        // The properties this element carried last render and no longer
        // describes. They are NAMED to the host, which clears each one, so a
        // modifier that stops being written costs that one property - not the
        // control, its handlers, and the state of every view under it. In
        // name order, because everything this side writes is.
        let lost = (rendered?.props.keys.filter { node.props[$0] == nil } ?? []).sorted()

        // Except for the few the host has no default to put back, which are
        // still the whole element again. See Prop.notCleared.
        let replace = rendered != nil
            && (rendered!.type != node.type || lost.contains { Prop.notCleared.contains($0) })

        // Nothing to build on: either this element is new, or what is there
        // cannot become what the node describes.
        let previous = replace ? nil : rendered

        if replace, let rendered = rendered {
            forget(rendered)
        }

        var patch = Patch(id: id, type: node.type)
        patch.replace = replace

        // How THIS element's values travel: what it was told about them, or
        // what the application says. Per node and never inherited - see
        // `Node.motion`. A plan answers per KIND of value, so a view may cross
        // to its new place on a spring and take its new size at once.
        let plan = node.motion
        let standing = motion
        let travel = { (values: MotionValues) in
            (plan?.motion(for: values) ?? .inherited).resolved(against: standing)
        }

        // What everything with no kind of its own travels at - which is what
        // an element's own motion means where no rule names a value.
        let travels = travel(.all)

        // Whether this layout's children are ROWS the host may keep and hand
        // to the next row of the same shape. Written when it CHANGES, like
        // every other field here: absent means unchanged, and a sparse patch
        // about a list whose rows merely moved must not say it again.
        //
        // A COMPLETE description is compared against the host's own default
        // rather than against this side's last render, and for one reason: the
        // host receiving it may be a fresh one, holding nothing. So a resync
        // says it only where it is TRUE, which is also what keeps a byte off
        // every node of every full message.
        // HOW THIS ELEMENT MOVES WHAT THE WIRE CANNOT DESCRIBE BESIDE: where it
        // puts its children, and what its VISUAL STATES change. Both are the
        // host's own arithmetic - a placement is worked out from a measurement,
        // and a state is applied by the platform, outside every message - so
        // neither has a property for a transition to ride beside. See
        // Core/Wire.swift, Field.motion.
        //
        // A control that travels the way the application does says NOTHING, on
        // any message, ever: `.inherited` is what a control is until it is told
        // otherwise, on both sides, so the common case is not on the wire at
        // all. What is said is an override, and its going away.
        //
        // A visual state is written as a CHILD, and `write(_:into:resting:)`
        // keeps them after whatever the control lays out - so the last child
        // is the whole of the question.
        //
        // And any element that answered `.motion(_:)` for itself, because what
        // the HOST decides follows that answer: where children go, what a
        // visual state changes, and whether showing and hiding crosses.
        if NodeType.saysMotion.contains(node.type)
            || node.states
            || plan?.base != nil {
            let mine = node.type == .application
                ? motion
                : (plan?.motion(for: .place).map { $0.isInherited ? .inherited : $0 }
                    ?? .inherited)

            // INHERITED until told otherwise, on both sides - so a layout that
            // travels the way the application does has nothing to say, on a
            // first render as much as on a patch. The application itself has no
            // such default and always says its own once.
            let was: Motion? = node.type == .application
                ? (describeAll ? nil : previous?.motion)
                : (describeAll ? .inherited : (previous?.motion ?? .inherited))

            // WHICH PARTS of a place travel. A layout told `.motion(.none,
            // .size)` puts its children in their new places and gives them
            // their new size at once, which is what a panel whose content
            // changes shape wants: a view growing out of nothing is the one
            // movement a reader reads as a fault.
            var lanes = MotionLanes.all

            if travel(.place).isNothing { lanes.subtract(.place) }
            if travel(.width).isNothing { lanes.subtract(.width) }
            if travel(.height).isNothing { lanes.subtract(.height) }

            let stood = describeAll ? MotionLanes.all : (previous?.lanes ?? .all)

            if was != mine || stood != lanes {
                patch.motion = mine
                patch.lanes = lanes
            }
        }

        if node.recycles != (describeAll ? false : (previous?.recycles ?? false)) {
            patch.recycles = node.recycles
        }

        // Nothing to clear on an element being described from scratch: the
        // patch is complete, so what is not in it was never set.
        patch.cleared = replace ? [] : lost

        // What `.onChanged` watches, against what this element carried last
        // time it was built. Nothing here reaches the patch: the comparison is
        // this side's alone, and the handlers are run by the renderer once the
        // message is packed. See Core/Changes.swift.
        //
        // Only against an element that is CONTINUING - a new one, or one being
        // replaced, has nothing to have changed from. A different count is a
        // different set of watches rather than a set that all moved, so it
        // starts over too.
        if let previous = previous, previous.watched.count == node.watches.count {
            for (index, watch) in node.watches.enumerated() {
                let old = previous.watched[index]

                // Nil means the stored value is of another type: that slot
                // changed hands, and a slot changing hands starts over.
                if watch.matches(old) == false {
                    let new = watch.value
                    fired.append { try await watch.run(old, new) }
                }
            }
        }

        // Properties. Everything when there is nothing to compare against, only
        // the differences when there is - and everything again on a resync.
        let changed = previous.map { was in
            node.props.filter { key, value in was.props[key] != value }
        } ?? node.props

        patch.props = describeAll ? node.props : changed

        // A property that is both ARMED and moving is a property to be walked
        // to. Asked in this order deliberately: the transition rides beside a
        // property the patch is already sending, so a flight to a value the
        // control already has says nothing - and is answered true when the
        // message is packed, because the model is where it was going.
        //
        // Iterated over a Dictionary, which is safe here and nowhere else:
        // what comes out of this goes into `patch.transitions`, and the wire
        // writes THAT sorted.
        // A write the author SNAPPED. The absence of a transition IS the snap,
        // so nothing is written here - what this collects is which properties
        // the ordinary motion below must leave alone.
        var snapped: Set<Prop> = []

        if !node.armed.isEmpty && !snapping.isEmpty {
            for (property, key) in node.armed where snapping.contains(key) {
                snapped.insert(property)
            }
        }

        if !node.armed.isEmpty && !flights.isEmpty {
            for (property, key) in node.armed where patch.props[property] != nil {
                guard let flight = flights[key] else { continue }

                patch.transitions[property] = Transition(
                    motion: flight.motion.resolved(against: travel(property.moving)),
                    channel: flight.channel,
                    report: flight.report)

                carried.insert(key)
            }
        }

        // EVERY OTHER PROPERTY THAT MOVED, TRAVELS. A value that changed is a
        // setpoint: the tree says where it is going and the host's engine takes
        // the control there, so a colour crosses to the colour it became and a
        // view that grew arrives at its size.
        //
        // On a CONTINUING element alone. An element being described for the
        // first time - built, replaced, resynced, or adopted under a fresh
        // identity - has no "before" to travel from, so the first thing anyone
        // sees is always the thing itself: first render at target is a fact of
        // these bytes and not something the host has to work out.
        //
        // Channel ZERO: nobody started this and nobody is waiting for it.
        //
        // Nothing is written for a value with no half-way - a string, a flag, a
        // member of an enumeration, a brush - and nothing at all when the
        // motion is none, where a snap costs exactly the bytes it always did.
        if !describeAll, !replace, previous != nil, plan != nil || !travels.isNothing {
            for (property, value) in patch.props
            where value.moves && !Prop.unmoved.contains(property)
                && patch.transitions[property] == nil
                && !snapped.contains(property) {
                let moves = travel(value.kind.union(property.moving))

                if moves.isNothing { continue }

                patch.transitions[property] = Transition(
                    motion: moves, channel: 0, report: 0)
            }
        }

        // Events. Ids are inherited so that an element C# is not being told
        // about goes on resolving the ids it already has.
        //
        // In name order, because a Dictionary has none: Swift seeds its hashing
        // per process, so the same tree would hand the same three events three
        // different ids on three different runs. Nothing breaks - the ids are
        // sent with the element that uses them - but two runs of one tree stop
        // being comparable, which is the same reason Core/Wire.swift writes
        // props and events in name order.
        //
        // A view that says what to do when it goes has to hear that it has come
        // BACK, or a walk cannot tell a view the platform unloaded from one
        // unloaded and shown again - and only the second of those has its own
        // leaving still to answer. Nothing an author wrote and nothing they
        // see: an empty handler, whose id is what the host reports the load on.
        // See `unloads`.
        var handled = node.events
        if handled[.unloaded] != nil, handled[.loaded] == nil {
            handled[.loaded] = {}
        }

        var events: [Event: Int] = [:]
        for (name, handler) in handled.sorted(by: { $0.key < $1.key }) {
            let handlerId = previous?.events[name] ?? allocateHandlerId()
            events[name] = handlerId
            handlers[handlerId] = handler

            // A view starts out showing. What it does after that is the host's
            // to say and never a walk's.
            if name == .unloaded, unloads[handlerId] == nil {
                unloads[handlerId] = false
            }
        }

        if let loaded = events[.loaded], let unloaded = events[.unloaded] {
            loads[loaded] = unloaded
        }

        if let previous = previous {
            // An event this element no longer handles takes its id with it.
            for (name, handlerId) in previous.events where events[name] == nil {
                handlers.removeValue(forKey: handlerId)
                unloads.removeValue(forKey: handlerId)
                loads.removeValue(forKey: handlerId)

                // `loads` is keyed by the LOADED id, so a removed `.onUnloaded`
                // is a VALUE in it - left there, every later load would re-seed
                // `unloads` for the dead id.
                for (loaded, unloaded) in loads where unloaded == handlerId {
                    loads.removeValue(forKey: loaded)
                }
            }
        }

        // Set when the event set CHANGED, so C# replaces its map. Empty counts
        // as a change only for a CONTINUING element - one whose last handler
        // went - because there an empty map MEANS "clear what you had"; for a
        // new element or a resync an empty set is nothing to say, and writing
        // it would put a redundant field on every eventless control. See
        // Core/Wire.swift, which now writes an empty set through rather than
        // skipping it.
        let eventsChanged = describeAll || previous == nil
            ? !events.isEmpty
            : Set(events.keys) != Set(previous!.events.keys)

        if eventsChanged {
            patch.events = events
        }

        // The properties tied to a bus. Asking each bus for its NUMBER is what
        // ISSUES one, so they are numbered in the order the tree is walked -
        // which is the order a fixture's sidecar reads in, and the reason two
        // runs of one tree number alike.
        //
        // Written when the set CHANGED, an emptied set included: an element
        // that stopped tying a property has to say so, or the host would go on
        // reading a bus for a property the tree has taken back. Compared as a
        // whole, so a bus swapped for another under the same property is a
        // change like any other.
        // IN NAME ORDER, because asking a bus for its number is what ISSUES
        // one: a Dictionary has no order and Swift salts its hashing per
        // process, so numbering them as they happen to be stored would give
        // one tree different numbers in two runs - and a fixture's bytes are
        // a contract. Sorted here, the numbers follow the walk and the names.
        var buses: [Prop: BusEntry] = [:]

        for key in node.buses.keys.sorted() {
            let registration = node.buses[key]!

            buses[key] = BusEntry(
                bus: registration.bus.bus,
                mode: registration.mode,
                kind: registration.kind)
        }

        let busesChanged = describeAll || previous == nil
            ? !buses.isEmpty
            : buses != previous!.buses

        if busesChanged {
            patch.buses = buses
        }

        let children = reconcileChildren(of: previous, node: node, into: &patch)

        let result = RenderedNode(
            id: id,
            type: node.type,
            props: node.props,
            events: events,
            recycles: node.recycles,
            motion: patch.motion ?? previous?.motion ?? .inherited,
            lanes: patch.motion == nil ? (previous?.lanes ?? .all) : patch.lanes,
            key: key,
            memo: memo,
            views: views,
            placeholder: placeholder,
            reads: reads,
            builds: builds,
            provided: Array(scope.suffix(pushed)),
            seen: seen,
            watched: node.watches.map { $0.value },
            engines: engines,
            buses: buses,
            children: children
        )

        return (result, patch)
    }

    // MARK: - Children

    /// Matches this render's children against the last one's, patches each, and
    /// says how they now stand when that changed.
    ///
    /// Where the identities come from is the whole of it: a child written with
    /// an `.id()` is found wherever it has moved to, one without is found by
    /// position. What the patch then carries is decided by ONE comparison, the
    /// id sequence against last render's: unchanged, and only the children
    /// with something to say are sent, each found again by its identity;
    /// changed - an addition, a removal and a move all change it - and the
    /// patch carries the COMPLETE list in order, the unchanged children as
    /// stubs. The list is then the whole story: its order, its length, and
    /// who is no longer in it.
    private func reconcileChildren(
        of previous: RenderedNode?,
        node: Node,
        into patch: inout Patch
    ) -> [RenderedNode] {
        let rendered = previous?.children ?? []

        var byManualId: [String: RenderedNode] = [:]
        var byKey: [String: RenderedNode] = [:]
        for child in rendered {
            if case .manual(let key) = child.id {
                byManualId[key] = child
            }

            // First wins, so two elements that somehow claim one path behave
            // like two siblings written with the same `.id()`: the second is
            // identified by where it stands instead.
            if let key = child.key, byKey[key] == nil {
                byKey[key] = child
            }
        }

        // The elements the builder did NOT write - a node put among them by
        // hand, the way a page appends its TitleView. They are still matched by
        // position, and by position among THEMSELVES: a conditional beside them
        // changes how many children there are, and counting past it would find
        // the wrong one.
        let unkeyed = rendered.filter { $0.key == nil }

        var children: [RenderedNode] = []
        var patches: [Patch] = []
        var claimed: Set<ElementId> = []
        var used: Set<ElementId> = []
        var unkeyedSoFar = 0
        var manualSeen: [String: Int] = [:]

        for (index, childNode) in node.children.enumerated() {
            // Two siblings written with the same `.id()`. C# matches children
            // by identity and one control cannot be in two places, so the
            // repeat cannot keep the bare id - but a fresh AUTOMATIC id every
            // render would rebuild its control, its handlers and its `@State`
            // each time and resend the arrangement each time. A STABLE variant
            // instead - the id with an occurrence number behind a NUL - is the
            // same identity every render, so the repeat keeps everything a
            // first-occurrence element would. A NUL cannot come out of a
            // `String(describing:)` an author wrote, so the variant can never
            // collide with an id someone spelled.
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

            // A backstop for a variant that somehow still collided - it never
            // should, the occurrence number making each unique.
            if used.contains(id) {
                id = .auto(allocateElementId())
            }

            used.insert(id)

            var (child, childPatch) = element(id: id, rendered: match, node: childNode)

            // What this row LOOKS like, so the host can hand its control to
            // the next row of the same shape. Only under a layout that says
            // its children are rows, and only when the number MOVED: a row
            // that starts writing a conditional property is a row the pool
            // must stop offering to the rows that do not write it. See
            // Core/Recycling.swift.
            if node.recycles {
                child.shape = Recycling.shape(of: child)

                // Against the host's default on a complete description, for
                // the reason the recycling flag is - see `element`.
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

        // The arrangement is described only when it changed. Sending it always
        // would make C# rearrange the child list on every render of a parent
        // whose children merely changed their text.
        if describeAll || children.map(\.id) != rendered.map(\.id) {
            patch.arranged = true
            patch.children = patches
        } else {
            patch.children = patches.filter { !$0.isEmpty }
        }

        return children
    }

    /// The rendered element a node continues, if any.
    ///
    /// Three ways to be the same element, in the order they are tried:
    ///
    /// 1. **The author's `id`** - a NAME, matched wherever the element has moved
    ///    to. This is what a collection needs, and what `ForEach` stamps from
    ///    its items.
    /// 2. **The builder's path** - WHERE it was written, matched wherever it has
    ///    moved to as well. Which statement, which branch; see `Node.key`. An
    ///    element from one branch of an `if` never matches one from the other,
    ///    and an element after a conditional does not move when the
    ///    conditional changes its mind.
    /// 3. **Position** - for a node put in by hand rather than by a builder, and
    ///    counted among the hand-written ones only.
    ///
    /// The three never meet: a node identified one way is never matched to an
    /// element identified another, so a `.id()` added to a view replaces the
    /// control rather than quietly adopting the one the path had.
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

    /// Starts a walk's scope over: the STANDARD providers first - the host's
    /// battery, connectivity, display and their kin, seeded at the bottom so
    /// any view resolves them with nothing provided, and an app's own
    /// `.environment()` deeper in the tree is nearer and wins. See
    /// Types/HostEnvironment.swift.
    private func seedScope() {
        scope.removeAll(keepingCapacity: true)
        scope.append(contentsOf: StandardEnvironment.scope)
    }

    /// The nearest provided object per type, by identity - what a memo's skip
    /// compares. Later entries are nearer, so a plain overwrite wins right.
    private func snapshot() -> [ObjectIdentifier: ObjectIdentifier] {
        var seen: [ObjectIdentifier: ObjectIdentifier] = [:]

        for entry in scope {
            seen[entry.key] = ObjectIdentifier(entry.object)
        }

        return seen
    }

    // MARK: - Identity

    /// The identity for an element being seen for the first time: the author's
    /// if there is one, otherwise a fresh number.
    private func identity(for node: Node) -> ElementId {
        node.id.map(ElementId.manual) ?? .auto(allocateElementId())
    }

    /// The next element identity. Never reused, ever.
    private func allocateElementId() -> Int {
        let id = nextElementId
        nextElementId += 1
        return id
    }

    /// The next handler id. Never reused either.
    private func allocateHandlerId() -> Int {
        let id = nextHandlerId
        nextHandlerId += 1
        return id
    }
}
