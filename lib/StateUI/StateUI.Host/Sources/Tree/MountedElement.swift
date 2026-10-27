// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// One element of the mounted tree: the runtime's live instance of a described node.
/// Design: docs/design/host/tree.md#the-mounted-tree
@_spi(Host) @MainActor public final class MountedElement {
    /// The element's key.
    public let id: ElementID

    /// The element's node type.
    public let type: NodeType

    /// The element's instance number, which its animations are filed under.
    public let mount: UInt64

    /// The element that holds this one.
    public private(set) weak var parent: MountedElement?

    /// The elements this one holds, in order - a grid's, a ZStack's and a phase layout's in the order they are
    /// drawn, by `zIndex`, ties in the order written.
    public private(set) var children: [MountedElement] = []

    /// What an arrangement of pages declares beside its pages - its actions, its menus, its title view - kept
    /// apart, so its children are its pages alone; nothing for any other element.
    /// Design: docs/design/host/tree.md#an-arrangements-slots
    public private(set) var slots: [MountedElement] = []

    /// Each child's place in the order the last arrangement wrote them - known before the children are made.
    private(set) var writingOrder: [ElementID: Int] = [:]

    /// The properties the patches described.
    public private(set) var properties: [Prop: HostValue] = [:]

    /// The properties bound to states, by property.
    public private(set) var driven: [Prop: HostStateBinding] = [:]

    /// The handlers of the events the tree listens to, by event.
    public private(set) var events: [Event: Int32] = [:]

    /// How this element's children animate, as its patches said; nil while it says nothing.
    public private(set) var motion: HostLayoutMotion?

    /// Whether this element's frame, or any frame under it, is read.
    public private(set) var framesRead = false

    /// Whether this page tree is shown, as its phases last told.
    public internal(set) var isPagePresented = false

    /// Whether the element fades out on its way to being hidden, which it still stands shown for.
    public internal(set) var isLeaving = false

    /// Whether this element was last told the focus stands in it.
    var reportedFocus = false

    /// The frame report this element last said, which a report the same says again to nobody.
    var reportedFrame: [Double] = []

    /// Where a split view last said its sidebar stands, and onto which state; nil before it said.
    var reportedOverlays: (binding: HostStateBinding, over: Bool)?

    /// Where the states a press dragged carries stood as it began.
    var dragStart = Point(x: 0, y: 0)

    /// A drag between views over the element's view, as the element tells it.
    var dropTarget = DropTarget()

    /// The hand over the element, where it is a layout a hand moves.
    var handReading = HandReading()

    /// What the hand said since the last frame, the moves between two frames as one, waiting for the next.
    var handOutbox: [HandReading.Report] = []

    /// Two fingers over the element, where it is a layout they move, and what they said since the last frame.
    var pinchReading = PinchReading()
    var pinchOutbox: [PinchReading.Report] = []

    /// A wheel turned as a pinch over the element, while one is under way.
    var wheelPinch = WheelPinch()

    /// A press on the view as a button takes it, while the view hears taps.
    var buttonPress = ButtonPress()

    /// Whether the hand over the layout took the presses in it, in the touch under way.
    var handTookPresses = false

    /// A press dragged with ⌥/Alt over the element, read as two fingers, while one is under way.
    var mirroredFingers = MirroredFingers()

    /// The toolkit's half of the element.
    public private(set) var native: (any NativeElement)!

    /// Whether the last patch changed the element's children - one added, moved, taken away or changed.
    public private(set) var childrenChanged = false

    /// Whether the patch last applied asks the element to arrange its children again: a new arrangement, a child made
    /// anew or drawn by the element, a page's own values - its title on a tab - a child's place, size or drawing
    /// order changed; not a change inside a child that stands where it stood.
    /// Design: docs/design/host/tree.md#a-patch-arranges-what-moved
    public private(set) var childrenNeedArranging = false

    /// The one the host keeps for this element as a child another's view draws, once one was asked for.
    var keptChild: HostChild?

    private(set) weak var tree: MountedTree?
    private var wornStates: [Int32] = []
    private var presentedStates: [Int32] = []
    private var drivenValues: [Prop: HostStateValue] = [:]
    private var created = false
    private var described = false

    /// Whether this popover is on its way to a view made anew (`showsAnew`).
    var isMoving = false

    /// How many elements are alive: those the tree holds, and any a host still holds after the tree dropped it.
    /// Design: docs/design/host/conformance.md#nothing-left-behind
    public private(set) static var liveCount = 0

    init(_ patch: HostPatch, tree: MountedTree, parent: MountedElement?) {
        Self.liveCount += 1
        id = patch.id
        type = patch.type
        self.tree = tree
        self.parent = parent
        mount = tree.allocateMount()
        native = nil
        tree.mounted(self)
        madeOrLeftByRender()
        made = patch
        native = tree.makeNative(self)
        made = nil
        tree.tally?.made += 1
        apply(patch)
    }

    isolated deinit {
        Self.liveCount -= 1
    }

    /// The patch the element is made from while its native half is made - what a toolkit making another control of
    /// what the element holds reads (`Reports.made`); nil after.
    public private(set) var made: HostPatch?

    /// Applies a patch of this element. The tree is made and applied by recursion - an element, then its children -
    /// through this frame, kept small: the element's own work is done in steps that return before its children are.
    /// Design: docs/design/host/runtime.md#the-mounts-stack
    public func apply(_ patch: HostPatch) {
        guard let tree else { return }

        let applying = received(patch, tree: tree)
        if case .unchanged = patch.children {} else { willShowAnew() }
        childrenApplied(patch.children, tree: tree)
        settled(patch, applying, tree: tree)
        if childrenChanged { showsAnew() }
    }

    /// What applying a patch carries from before the children to after them: when a scene began, the pages shown,
    /// the properties that changed and the values they stood at.
    private final class Applying {
        let sceneBegan: ContinuousClock.Instant?
        let previouslyShown: [MountedElement]
        let changed: Set<Prop>
        let received: Set<Prop>
        let standing: [Prop: HostValue]
        let untouched: Bool

        init(
            sceneBegan: ContinuousClock.Instant?, previouslyShown: [MountedElement], changed: Set<Prop>,
            received: Set<Prop>, standing: [Prop: HostValue], untouched: Bool
        ) {
            self.sceneBegan = sceneBegan
            self.previouslyShown = previouslyShown
            self.changed = changed
            self.received = received
            self.standing = standing
            self.untouched = untouched
        }
    }

    /// The patch's own values taken: its properties, events, driven states and motion, before its children.
    @inline(never)
    private func received(_ patch: HostPatch, tree: MountedTree) -> Applying {
        let sceneBegan: ContinuousClock.Instant? = tree.tally != nil && patch.type == .scene ? .now : nil
        tree.tally?.nodes += 1

        let previouslyShown = isPagePresented ? shownChildren : []
        let heardPull = hearsPull
        var changed = Set(patch.clearedProperties)
        changed.formUnion(patch.properties.keys)
        if case .replace(let replacement) = patch.driven {
            changed.formUnion(driven.keys)
            changed.formUnion(replacement.keys)
        }

        // Nothing of an element being made runs to be cut short: it receives what it animates and what a state drives,
        // whose channel its first reading opens.
        var bound: Set<Prop> = []
        if case .replace(let driven) = patch.driven { bound = Set(driven.keys) }
        let received = described ? changed : changed.filter { patch.transitions[$0] != nil || bound.contains($0) }
        let standing = Dictionary(uniqueKeysWithValues: received.compactMap { property in
            standingValue(property, target: patch.properties[property]).map { (property, $0) }
        })

        for property in patch.clearedProperties {
            properties[property] = nil
        }

        for (property, value) in patch.properties {
            properties[property] = value
        }

        var eventsReplaced = false
        if case .replace(let events) = patch.events {
            self.events = events
            eventsReplaced = true
        }

        if case .replace(let driven) = patch.driven {
            self.driven = driven
            drivenValues = drivenValues.filter { driven[$0.key] != nil }
            let presented = driven.values.filter { $0.mode != .in }.map(\.state).sorted()
            if presented != presentedStates {
                tree.presents(self, presented, before: presentedStates)
                presentedStates = presented
            }
        }
        wear(driven)

        for (property, binding) in driven where binding.mode != .in {
            drivenValues[property] = tree.core.value(for: binding)
        }
        // What hears the pull changed: the offer its view is given follows (`offeredRefresh`).
        if hearsPull != heardPull { changed.insert(.isRefreshEnabled) }

        if let motion = patch.motion {
            self.motion = motion
            // The application says its motion once; every layout that says none animates under it.
            if type == .application { tree.layoutMotion.applicationMotion = motion.motion }
        }

        if case .unchanged = patch.children { childrenChanged = false } else { childrenChanged = true }
        if described, !changed.isEmpty || eventsReplaced { changedByRender(changed) }

        // A child a new arrangement names for its order alone: nothing of it changed.
        let untouched = described && changed.isEmpty && !eventsReplaced && patch.motion == nil && !childrenChanged
        return Applying(
            sceneBegan: sceneBegan, previouslyShown: previouslyShown, changed: changed, received: received,
            standing: standing, untouched: untouched)
    }

    /// The children the patch arranges or changes, made or applied.
    private func childrenApplied(_ children: HostChildrenUpdate, tree: MountedTree) {
        switch children {
        case .unchanged:
            childrenNeedArranging = false

        case .arranged(let childPatches):
            writingOrder = Dictionary(childPatches.enumerated().map { ($1.id, $0) }) { first, _ in first }
            arrange(childPatches, tree: tree)
            childrenNeedArranging = true

        case .changed(let childPatches):
            for childPatch in childPatches {
                applied(childPatch, tree: tree)
            }
            childrenNeedArranging = childPatches.contains(where: asksArranging)
        }
    }

    /// Whether `childPatch` asks this element to arrange its children again (`childrenNeedArranging`).
    private func asksArranging(_ childPatch: HostPatch) -> Bool {
        let ownValues = !childPatch.properties.isEmpty || !childPatch.clearedProperties.isEmpty
        if childPatch.replace || childPatch.driven != nil || childPatch.motion != nil
            || NodeType.pageTypes.contains(childPatch.type) && ownValues {
            return true
        }
        let child = children.first { $0.id == childPatch.id } ?? slots.first { $0.id == childPatch.id }
        guard let child, child.native.presentsView else { return true }
        // What its measure reads may size it anew - its words - as its place, size and drawing order move it.
        return childPatch.properties.keys.contains { !Self.unmeasuredProperties.contains($0) }
            || childPatch.clearedProperties.contains { !Self.unmeasuredProperties.contains($0) }
    }

    /// A child the patch names among those it has, applied - or made again where it is replaced.
    private func applied(_ childPatch: HostPatch, tree: MountedTree) {
        // A new child arrives only in an arranged list; a sparse list naming a stranger drifted.
        let isSlot = holdsSlotsApart && NodeType.slotTypes.contains(childPatch.type)
        guard let index = (isSlot ? slots : children).firstIndex(where: { $0.id == childPatch.id }) else {
            tree.intake.drifted("a patch names child '\(childPatch.id)' that '\(id)' does not have")
            return
        }
        let child = isSlot ? slots[index] : children[index]

        if child.type == childPatch.type, !childPatch.replace {
            child.apply(childPatch)
        } else if childPatch.replace {
            child.leave()
            let anew = MountedElement(childPatch, tree: tree, parent: self)
            if isSlot { slots[index] = anew } else { children[index] = anew }
            changedByRender([])
        } else {
            tree.intake.drifted(
                "a patch describes '\(childPatch.id)' as \(childPatch.type) where '\(id)' holds \(child.type)")
        }
    }

    /// The patch's changes told to the native half, its children in place: each property, the stacking, the
    /// enablement and the direction, the frames read and the pages presented.
    @inline(never)
    private func settled(_ patch: HostPatch, _ applying: Applying, tree: MountedTree) {
        let changed = applying.changed
        for property in applying.received.sorted() {
            let hasDrivenPresentation = driven[property].map { $0.mode != .in } ?? false
            tree.receiveProperty(
                mount: mount,
                property: property,
                standing: applying.standing[property],
                target: resolvedValue(property) ?? identity(of: property),
                motion: hasDrivenPresentation || !native.animates(property)
                    ? nil
                    : patch.transitions[property]?.motion)
        }

        if restack(), described { reorderedByRender() }
        if changed.contains(.isEnabled), described { enablementTurned() }
        if changed.contains(.layoutDirection) {
            directionTurned(arrangingItself: false)
        } else if !described {
            native.directionChanged()
        }
        framesRead = driven[.frame] != nil || events[.frameChanged] != nil
            || held.contains { $0.framesRead }
        // Made in a disabled branch, it presents an `isEnabled` it never wrote; a page made under an arrangement's
        // ground, a `background` it never wrote; untouched, it presents nothing.
        var presenting = changed
        if !described, parent?.isEffectivelyEnabled == false { presenting.insert(.isEnabled) }
        if !described, type == .page, value(.background) == nil, pageBackground != nil { presenting.insert(.background) }
        if !applying.untouched { native.applied(changed: presenting, wasDescribed: described) }
        described = true
        reconcilePresentation(from: applying.previouslyShown)

        if let sceneBegan = applying.sceneBegan {
            tree.tally?.scenes[patch.id, default: .zero] += ContinuousClock.now - sceneBegan
        }
    }

    /// Tells the element's handler of `event` as a phase, rendered in its turn before what comes after it.
    func tellPhase(_ event: Event) {
        guard let handler = handler(event) else { return }
        tree?.tellPhase(handler)
    }

    /// Reconciles a complete child arrangement by key - an arrangement of pages keeping its slots apart.
    private func arrange(_ patches: [HostPatch], tree: MountedTree) {
        let before = held
        let previous = Self.byId(before)
        var children: [MountedElement] = []
        var slots: [MountedElement] = []

        // The children first, then the pages kept apart, each in its order.
        for patch in patches where !isSlot(patch) {
            children.append(mounted(patch, continuing: previous[patch.id], tree: tree))
        }
        for patch in patches where isSlot(patch) {
            slots.append(mounted(patch, continuing: previous[patch.id], tree: tree))
        }
        self.children = children
        self.slots = slots
        leave(before)
        if described { arrangedByRender(from: before) }
    }

    /// `elements` by their identity, the first of two that share one.
    @inline(never)
    private static func byId(_ elements: [MountedElement]) -> [ElementID: MountedElement] {
        Dictionary(elements.map { ($0.id, $0) }) { first, _ in first }
    }

    /// Whether `patch` describes a page this arrangement keeps apart.
    private func isSlot(_ patch: HostPatch) -> Bool {
        holdsSlotsApart && NodeType.slotTypes.contains(patch.type)
    }

    /// The child `patch` describes: `standing` applied where it is the same kind of element, made anew otherwise.
    private func mounted(_ patch: HostPatch, continuing standing: MountedElement?, tree: MountedTree) -> MountedElement {
        if let child = standing, child.type == patch.type, !patch.replace {
            child.parent = self
            child.apply(patch)
            return child
        }

        return MountedElement(patch, tree: tree, parent: self)
    }

    /// Whether this element is an arrangement of pages, whose children are its pages alone.
    private var holdsSlotsApart: Bool { Self.arrangements.contains(type) }

    /// Everything this element holds: its children, then its slots.
    var held: [MountedElement] { children + slots }

    /// The arrangements of pages, which keep their slots apart from their pages.
    private static let arrangements: Set<NodeType> = [.navigationStack, .tabView, .splitView]

    /// Puts a grid's or a ZStack's children in the order they are drawn: by `zIndex`, ties in the order
    /// written. Answers whether the order moved.
    /// Design: docs/design/host/layout.md#drawing-order
    @discardableResult
    private func restack() -> Bool {
        guard Self.layered.contains(type), children.count > 1 else { return false }

        let drawnBefore = { (lhs: MountedElement, rhs: MountedElement) -> Bool in
            let (lower, upper) = (lhs.zIndex, rhs.zIndex)
            if lower != upper { return lower < upper }
            return (self.writingOrder[lhs.id] ?? .max) < (self.writingOrder[rhs.id] ?? .max)
        }
        guard zip(children, children.dropFirst()).contains(where: { drawnBefore($1, $0) }) else { return false }
        children.sort(by: drawnBefore)
        return true
    }

    /// The direction this element lays out in turned: it and every element under it that inherits the direction
    /// hear it, and every layout among them arranges its children again, the element itself when its patch will not.
    /// Design: docs/design/host/layout.md#right-to-left
    func directionTurned(arrangingItself: Bool) {
        native.directionChanged()
        if arrangingItself, !children.isEmpty { native.arrangeChildren() }
        for child in children where child.inheritsDirection {
            child.directionTurned(arrangingItself: true)
        }
    }

    /// Whether this element says no direction of its own.
    private var inheritsDirection: Bool {
        LayoutDirection(rawValue: value(.layoutDirection)?.enumeration ?? 0).map { $0 == .inherited } ?? true
    }

    /// Where this element is drawn among its overlapping siblings, higher nearer the front.
    private var zIndex: Double { number(.zIndex) ?? 0 }

    /// The layouts whose children can overlap, drawn in `zIndex` order.
    private static let layered: Set<NodeType> = [.grid, .zStack, .phaseLayout]

    /// Detaches every one of `previous` that is no longer a child.
    private func leave(_ previous: [MountedElement]) {
        let staying = Set(held.map(ObjectIdentifier.init))
        for child in previous where !staying.contains(ObjectIdentifier(child)) {
            child.leave()
        }
    }

    /// Ties this element to the channels of the states its properties wear.
    private func wear(_ driven: [Prop: HostStateBinding]) {
        let worn = driven.values.filter { $0.kind == .property }.map(\.state).sorted()
        guard worn != wornStates, let tree else { return }

        for state in wornStates { tree.stateChannels.detach(state) }
        for state in worn { tree.stateChannels.attach(state) }
        wornStates = worn
    }

    /// Detaches this element and everything under it from the runtime as it leaves the tree.
    /// Design: docs/design/host/tree.md#leaving
    public func leave() {
        madeOrLeftByRender()
        if let tree {
            for state in wornStates { tree.stateChannels.detach(state) }
            tree.removeMotions(mount: mount)
            tree.unmounted(self, presenting: presentedStates)
        }
        wornStates = []
        presentedStates = []
        isLeaving = false
        native.leave()
        for child in held { child.leave() }
    }

    /// The first element of `type` in this subtree, this one first.
    public func first(type sought: NodeType) -> MountedElement? {
        if type == sought { return self }

        for child in held {
            if let found = child.first(type: sought) { return found }
        }

        return nil
    }

    /// The nearest element of `type` holding this one, this one first.
    public func enclosing(type sought: NodeType) -> MountedElement? {
        var element: MountedElement? = self
        while let each = element, each.type != sought { element = each.parent }
        return element
    }

    /// The window elements in this subtree, in the tree's order; a window holds none.
    public var windows: [MountedElement] {
        type == .window ? [self] : children.flatMap(\.windows)
    }

    /// The pages in this subtree, in the tree's order, this one first.
    public var pages: [MountedElement] {
        (type == .page ? [self] : []) + held.flatMap(\.pages)
    }

    /// The first element with key `sought` in this subtree, this one first.
    public func first(id sought: ElementID) -> MountedElement? {
        if id == sought { return self }

        for child in held {
            if let found = child.first(id: sought) { return found }
        }

        return nil
    }

    /// The element numbered `sought` in this subtree, this one first; nil where none is.
    public func first(mount sought: UInt64) -> MountedElement? {
        if mount == sought { return self }

        for child in held {
            if let found = child.first(mount: sought) { return found }
        }

        return nil
    }

    /// Every element with key `sought` in this subtree.
    public func all(id sought: ElementID) -> [MountedElement] {
        var found = id == sought ? [self] : []
        for child in held {
            found.append(contentsOf: child.all(id: sought))
        }
        return found
    }

    /// The handlers of `created` raised by no render yet, in tree order; a window raises its own.
    public func takeCreatedHandlers() -> [Int32] {
        var handlers: [Int32] = []

        if !created {
            created = true
            if type != .window, let handler = events[.created] {
                handlers.append(handler)
            }
        }

        for child in held {
            handlers.append(contentsOf: child.takeCreatedHandlers())
        }

        return handlers
    }

    /// Drops the first element in this subtree that `matches`, as a runtime that lost part of its tree would.
    public func forgetForTesting(where matches: (MountedElement) -> Bool) {
        if let index = children.firstIndex(where: matches) {
            children[index].leave()
            children.remove(at: index)
            return
        }
        for child in held { child.forgetForTesting(where: matches) }
    }

    /// Presents one frame on the elements it touches - those presenting a state that moved or holding a property
    /// that moved - and what that asks of the elements around them, deepest first: each parent arranges once,
    /// after its children; one showing no view of its own passes its children's moves on to its own parent; one
    /// whose child's order moved draws its children in order again. No other element is visited.
    /// Design: docs/design/host/runtime.md#one-frame
    static func presentFrame(
        _ touched: [MountedElement],
        states valuesByState: [Int32: HostStateValue],
        properties propertiesByMount: [UInt64: Set<Prop>]
    ) -> FrameImpact {
        struct Waiting {
            let element: MountedElement
            var descendants = FrameImpact.none
            var restacks = false
        }
        func depth(of element: MountedElement) -> Int {
            var depth = 0
            var above = element.parent
            while let each = above {
                depth += 1
                above = each.parent
            }
            return depth
        }

        var waiting: [UInt64: Waiting] = [:]
        var byDepth: [Int: [UInt64]] = [:]
        for element in touched {
            waiting[element.mount] = Waiting(element: element)
            byDepth[depth(of: element), default: []].append(element.mount)
        }
        guard let deepest = byDepth.keys.max() else { return .none }

        var impact = FrameImpact.none
        for level in stride(from: deepest, through: 0, by: -1) {
            for mount in (byDepth[level] ?? []).sorted() {
                guard let entry = waiting[mount] else { continue }
                let element = entry.element
                element.tree?.frameVisits += 1

                var changed = propertiesByMount[mount] ?? []
                for (property, binding) in element.driven where binding.mode != .in {
                    guard let value = valuesByState[binding.state] else { continue }
                    element.drivenValues[property] = value
                    changed.insert(property)
                }

                let own = changed.isEmpty ? FrameImpact.none : element.presentFrame(changed)
                // A child's place is its parent's business; an element with no view passes it up.
                let restacked = entry.restacks && element.restack()
                if own.arrangesChildren || entry.descendants.arrangement || restacked {
                    element.native.arrangeChildren()
                }
                var passed = entry.descendants
                if element.native.presentsView { passed.arrangement = false }
                let said = own.union(passed)
                impact.arrangesChildren = impact.arrangesChildren || said.arrangesChildren
                impact.windowChrome = impact.windowChrome || said.windowChrome

                guard let parent = element.parent else {
                    impact.arrangement = said.arrangement
                    continue
                }
                let ordered = changed.contains(.zIndex)
                guard said.arrangement || ordered else { continue }

                if waiting[parent.mount] == nil {
                    waiting[parent.mount] = Waiting(element: parent)
                    byDepth[level - 1, default: []].append(parent.mount)
                }
                if said.arrangement { waiting[parent.mount]?.descendants.arrangement = true }
                if ordered { waiting[parent.mount]?.restacks = true }
            }
        }
        return impact
    }

    /// Presents `changed` on a frame and says what that asks around the element, the same on every host: its own
    /// presentation; its parent's arrangement where it moved in its slot or shows no view of its own, being drawn
    /// by its parent's; the window's chrome where the chrome shows what moved.
    /// Design: docs/design/host/runtime.md#one-frame
    private func presentFrame(_ changed: Set<Prop>) -> FrameImpact {
        native.presentFrame(changed)
        let moved = changed.subtracting(ownPlacementRun)
        return FrameImpact(
            arrangesChildren: !moved.subtracting(Self.drawnOverProperties).isEmpty,
            arrangement: !native.presentsView || !moved.isDisjoint(with: Self.arrangedProperties),
            windowChrome: WindowChrome.follows(type, changed: changed))
    }

    /// The value `property` presents: a running animation's, else the described or bound one.
    public func value(_ property: Prop) -> HostValue? {
        if driven[property].map({ $0.mode != .in }) == true {
            return resolvedValue(property)
        }

        return tree?.presentedPropertyValue(mount: mount, property: property) ?? resolvedValue(property)
    }

    /// The text value of `property`.
    public func string(_ property: Prop) -> String? { value(property)?.string }

    /// The name value of `property`.
    public func name(_ property: Prop) -> String? { value(property)?.name }

    /// The number value of `property`.
    public func number(_ property: Prop) -> Double? { value(property)?.number }

    /// The Boolean value of `property`.
    public func bool(_ property: Prop) -> Bool? { value(property)?.bool }

    /// The four sides `property` gives - leading, top, trailing, bottom - or nothing all round where it gives none.
    public func insets(_ property: Prop) -> Insets {
        guard let sides = value(property)?.numbers, sides.count >= 4 else { return Insets(0) }
        return Insets(start: sides[0], top: sides[1], end: sides[2], bottom: sides[3])
    }

    /// The handler of `event`, when the tree listens to it.
    public func handler(_ event: Event) -> Int32? { events[event] }

    /// The direction this element lays out in: its own, or where it inherits, its parent's - the
    /// language's at the root, as the host reported the locale.
    /// Design: docs/design/host/layout.md#right-to-left
    public var layoutDirection: LayoutDirection {
        switch value(.layoutDirection)?.enumeration.flatMap(LayoutDirection.init(rawValue:)) {
        case .leftToRight?: return .leftToRight
        case .rightToLeft?: return .rightToLeft
        default: return parent?.layoutDirection ?? tree?.core.languageDirection ?? .leftToRight
        }
    }

    /// What a layout reads of this element as its child.
    /// Design: docs/design/host/layout.md#the-layout-arithmetic
    public var layoutValues: LayoutValues {
        var values = LayoutValues()
        if let sides = value(.margin)?.numbers, sides.count >= 4 {
            values.margin = insets(.margin)
        }
        values.horizontal = value(.horizontalAlignment)?.enumeration ?? 3
        values.vertical = value(.verticalAlignment)?.enumeration ?? 3
        values.width = stated(.width)
        values.height = stated(.height)
        values.minimumWidth = stated(.minimumWidth)
        values.minimumHeight = stated(.minimumHeight)
        values.maximumWidth = stated(.maximumWidth)
        values.maximumHeight = stated(.maximumHeight)
        values.row = whole(.gridRow) ?? 0
        values.column = whole(.gridColumn) ?? 0
        values.rowSpan = max(whole(.gridRowSpan) ?? 1, 1)
        values.columnSpan = max(whole(.gridColumnSpan) ?? 1, 1)
        values.area = value(.area).flatMap(Area.init(propValue:))
        values.grows = type == .space
        values.words = NodeType.laidOutWords[type] ?? .none
        return values
    }

    /// A size the element states for itself; a negative one asks to be measured.
    private func stated(_ property: Prop) -> Double? {
        guard let value = number(property), value.isFinite, value >= 0 else { return nil }
        return value
    }

    private func whole(_ property: Prop) -> Int? {
        guard let number = value(property)?.number, number.isFinite else { return nil }
        return Int(number.rounded())
    }

    /// The bound state's value for `property`, as the last frame carried it or the core holds it.
    public func carriedValue(_ property: Prop) -> HostStateValue? {
        guard let binding = driven[property] else { return nil }
        return drivenValues[property] ?? tree?.core.value(for: binding)
    }

    /// Where `property` is headed: the destination of the journey its state carries it on; nil where no state does.
    public func destination(_ property: Prop) -> HostValue? {
        guard let binding = driven[property], binding.mode != .in, binding.kind == .property,
              let carried = carriedValue(property),
              let journey = HostBoundary.journey(from: tree?.presentedValue(for: binding, from: carried) ?? carried)
        else { return nil }
        return Self.value(of: journey.destination, as: binding.laneKind)
    }

    /// The value `property` settles at: the bound state's, else the described one.
    public func resolvedValue(_ property: Prop) -> HostValue? {
        guard let binding = driven[property], binding.mode != .in else {
            return properties[property]
        }

        guard let state = drivenValues[property] ?? tree?.core.value(for: binding) else {
            return properties[property]
        }

        switch (binding.kind, state) {
        case (.text, .text(let text)):
            return .string(text)

        case (.plain, .lanes(let lanes)):
            return Self.value(of: lanes, as: binding.laneKind)

        case (.property, let carried):
            let presented = tree?.presentedValue(for: binding, from: carried) ?? carried
            guard let journey = HostBoundary.journey(from: presented) else {
                return properties[property]
            }
            return Self.value(of: journey.value, as: binding.laneKind)

        default:
            return properties[property]
        }
    }

    /// Where `property` stands before a change animates it.
    /// Design: docs/design/host/tree.md#standing-values
    private func standingValue(_ property: Prop, target: HostValue?) -> HostValue? {
        if let presented = tree?.presentedPropertyValue(mount: mount, property: property) {
            return presented
        }
        if let native = native.standingValue(property) { return native }
        if let value = resolvedValue(property) { return value }
        guard native.animates(property) else { return nil }

        switch property {
        case .margin, .padding:
            return .numbers([0, 0, 0, 0])
        case .spacing, .rowSpacing, .columnSpacing:
            return .number(0)
        case .lineWidth:
            return .number(1)
        case .dashPhase, .x1, .y1, .x2, .y2:
            return .number(0)
        case .miterLimit:
            return .number(10)
        case .cornerRadius:
            if target?.number != nil {
                return .number(0)
            }
            if let radii = target?.numbers, radii.count == 4 {
                return .numbers(Array(repeating: 0, count: radii.count))
            }
            return nil
        default:
            return identity(of: property)
        }
    }

    /// What a transform the tree states none of stands at, on every host: no turn, no shift, a scale of one. A
    /// transform taken away travels back there, as it traveled out from there.
    /// Design: docs/design/host/tree.md#standing-values
    private func identity(of property: Prop) -> HostValue? {
        switch property {
        case .rotation, .translationX, .translationY:
            .number(0)
        case .scale:
            .number(1)
        case .scaleX, .scaleY:
            .number(resolvedValue(.scale)?.number ?? 1)
        case .geometryTransform:
            .values([
                .number(1), .number(0), .number(0),
                .number(1), .number(0), .number(0),
            ])
        default:
            nil
        }
    }

    /// A bound state's lanes as the value its type says they are, each type reading them as it laid them;
    /// nothing for text, which has no lanes.
    static func value(of lanes: [Double], as kind: HostLaneKind?) -> HostValue? {
        guard !lanes.isEmpty, let kind else { return nil }

        switch kind {
        case .number:
            return lanes.count == 1 ? .number(lanes[0]) : .numbers(lanes)
        case .boolean:
            return Bool(carried: .lanes(lanes))?.propValue
        case .choice:
            return .enumeration(Int32(lanes[0].rounded()))
        case .color:
            return Color(carried: .lanes(lanes))?.propValue
        case .material:
            return Material.propValue(lanes: lanes)
        }
    }
}
