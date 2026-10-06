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

    /// The elements this one holds, in order - a grid's and a ZStack's in the order they are drawn, by
    /// `zIndex`, ties in the order written.
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

    /// The frame report this element last said, which a report the same says again to nobody.
    var reportedFrame: [Double] = []

    /// Where the states a press dragged carries stood as it began.
    var dragStart = Point(x: 0, y: 0)

    /// A drag between views over the element's view, as the element tells it.
    var dropTarget = DropTarget()

    /// The toolkit's half of the element.
    public private(set) var native: (any NativeElement)!

    /// Whether the last patch changed the element's children - one added, moved, taken away or changed.
    public private(set) var childrenChanged = false

    /// The one the host keeps for this element as a child another's view draws, once one was asked for.
    var keptChild: HostChild?

    private(set) weak var tree: MountedTree?
    private var wornStates: [Int32] = []
    private var drivenValues: [Prop: HostStateValue] = [:]
    private var created = false
    private var described = false

    init(_ patch: HostPatch, tree: MountedTree, parent: MountedElement?) {
        id = patch.id
        type = patch.type
        self.tree = tree
        self.parent = parent
        mount = tree.allocateMount()
        native = nil
        native = tree.makeNative(self)
        tree.tally?.made += 1
        apply(patch)
    }

    /// Applies a patch of this element.
    public func apply(_ patch: HostPatch) {
        guard let tree else { return }

        let sceneBegan: ContinuousClock.Instant? = tree.tally != nil && patch.type == .scene ? .now : nil
        tree.tally?.nodes += 1
        defer {
            if let sceneBegan { tree.tally?.scenes[patch.id, default: .zero] += ContinuousClock.now - sceneBegan }
        }

        let previouslyShown = isPagePresented ? shownChildren : []
        var changed = Set(patch.clearedProperties)
        changed.formUnion(patch.properties.keys)
        if case .replace(let replacement) = patch.driven {
            changed.formUnion(driven.keys)
            changed.formUnion(replacement.keys)
        }

        let standing = Dictionary(uniqueKeysWithValues: changed.compactMap { property in
            standingValue(property, target: patch.properties[property]).map { (property, $0) }
        })

        for property in patch.clearedProperties {
            properties[property] = nil
        }

        for (property, value) in patch.properties {
            properties[property] = value
        }

        if case .replace(let events) = patch.events {
            self.events = events
        }

        if case .replace(let driven) = patch.driven {
            self.driven = driven
            drivenValues = drivenValues.filter { driven[$0.key] != nil }
        }
        wear(driven)

        for (property, binding) in driven where binding.mode != .in {
            drivenValues[property] = tree.core.value(for: binding)
        }

        if let motion = patch.motion {
            self.motion = motion
            // The application says its motion once; every layout that says none animates under it.
            if type == .application { tree.layoutMotion.applicationMotion = motion.motion }
        }

        if case .unchanged = patch.children { childrenChanged = false } else { childrenChanged = true }

        switch patch.children {
        case .unchanged:
            break

        case .arranged(let childPatches):
            writingOrder = Dictionary(childPatches.enumerated().map { ($1.id, $0) }) { first, _ in first }
            arrange(childPatches, tree: tree)

        case .changed(let childPatches):
            for childPatch in childPatches {
                // A new child arrives only in an arranged list; a sparse list naming a stranger drifted.
                let isSlot = holdsSlotsApart && NodeType.slotTypes.contains(childPatch.type)
                guard let index = (isSlot ? slots : children).firstIndex(where: { $0.id == childPatch.id }) else {
                    tree.intake.drifted("a patch names child '\(childPatch.id)' that '\(id)' does not have")
                    continue
                }
                let child = isSlot ? slots[index] : children[index]

                if child.type == childPatch.type, !childPatch.replace {
                    child.apply(childPatch)
                } else if childPatch.replace {
                    child.leave()
                    let anew = MountedElement(childPatch, tree: tree, parent: self)
                    if isSlot { slots[index] = anew } else { children[index] = anew }
                } else {
                    tree.intake.drifted(
                        "a patch describes '\(childPatch.id)' as \(childPatch.type) where '\(id)' holds \(child.type)")
                }
            }
        }

        for property in changed.sorted() {
            let hasDrivenPresentation = driven[property].map { $0.mode != .in } ?? false
            tree.receiveProperty(
                mount: mount,
                property: property,
                standing: standing[property],
                target: resolvedValue(property),
                motion: hasDrivenPresentation || !native.animates(property)
                    ? nil
                    : patch.transitions[property]?.motion)
        }

        restack()
        if changed.contains(.isEnabled), described { enablementTurned() }
        if changed.contains(.layoutDirection) {
            directionTurned(arrangingItself: false)
        } else if !described {
            native.directionChanged()
        }
        framesRead = driven[.frame] != nil || events[.frameChanged] != nil
            || held.contains { $0.framesRead }
        // Made in a disabled branch, it presents an `isEnabled` it never wrote.
        let presenting = !described && parent?.isEffectivelyEnabled == false ? changed.union([.isEnabled]) : changed
        native.applied(changed: presenting, wasDescribed: described)
        described = true
        reconcilePresentation(from: previouslyShown)
    }

    /// Tells the element's handler of `event` as a phase, rendered in its turn before what comes after it.
    func tellPhase(_ event: Event) {
        guard let handler = handler(event) else { return }
        tree?.tellPhase(handler)
    }

    /// Reconciles a complete child arrangement by key - an arrangement of pages keeping its slots apart.
    private func arrange(_ patches: [HostPatch], tree: MountedTree) {
        let before = held
        let previous = Dictionary(before.map { ($0.id, $0) }) { first, _ in first }
        let mounted = { (patch: HostPatch) -> MountedElement in
            if let child = previous[patch.id], child.type == patch.type, !patch.replace {
                child.parent = self
                child.apply(patch)
                return child
            }

            return MountedElement(patch, tree: tree, parent: self)
        }

        let isSlot = { (patch: HostPatch) in self.holdsSlotsApart && NodeType.slotTypes.contains(patch.type) }
        children = patches.filter { !isSlot($0) }.map(mounted)
        slots = patches.filter(isSlot).map(mounted)
        leave(before)
    }

    /// Whether this element is an arrangement of pages, whose children are its pages alone.
    private var holdsSlotsApart: Bool { Self.arrangements.contains(type) }

    /// Everything this element holds: its children, then its slots.
    private var held: [MountedElement] { children + slots }

    /// The arrangements of pages, which keep their slots apart from their pages.
    private static let arrangements: Set<NodeType> = [.navigationStack, .tabView, .splitView, .modalStack]

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
    private static let layered: Set<NodeType> = [.grid, .zStack]

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
        if let tree {
            for state in wornStates { tree.stateChannels.detach(state) }
            tree.removeMotions(mount: mount)
        }
        wornStates = []
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

    /// The first element with key `sought` in this subtree, this one first.
    public func first(id sought: ElementID) -> MountedElement? {
        if id == sought { return self }

        for child in held {
            if let found = child.first(id: sought) { return found }
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

    /// Presents one frame in one walk: bound states' values and moved properties, each parent arranged once.
    /// Design: docs/design/host/runtime.md#one-frame
    @discardableResult
    public func applyFrame(
        states valuesByState: [Int32: HostStateValue],
        properties propertiesByMount: [UInt64: Set<Prop>]
    ) -> FrameImpact {
        var changed = propertiesByMount[mount] ?? []

        for (property, binding) in driven where binding.mode != .in {
            guard let value = valuesByState[binding.state] else { continue }
            drivenValues[property] = value
            changed.insert(property)
        }

        let own = changed.isEmpty ? FrameImpact.none : presentFrame(changed)
        var descendants = FrameImpact.none

        for child in held {
            descendants = descendants.union(child.applyFrame(states: valuesByState, properties: propertiesByMount))
        }

        // A child's place is its parent's business; an element with no view passes it up.
        let restacked = restack()
        if own.content || descendants.arrangement || restacked { native.arrangeChildren() }
        guard native.presentsView else { return own.union(descendants) }
        descendants.arrangement = false
        return own.union(descendants)
    }

    /// Presents `changed` on a frame and says what that asks around the element, the same on every host: its own
    /// presentation; its parent's arrangement where it moved in its slot or shows no view of its own, being drawn
    /// by its parent's; the window's chrome where the chrome shows what moved.
    /// Design: docs/design/host/runtime.md#one-frame
    private func presentFrame(_ changed: Set<Prop>) -> FrameImpact {
        native.presentFrame(changed)
        return FrameImpact(
            content: true,
            arrangement: !native.presentsView
                || !changed.subtracting(ownPlacementRun).isDisjoint(with: Self.arrangedProperties),
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
        return Insets(left: sides[0], top: sides[1], right: sides[2], bottom: sides[3])
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
        case .rotation, .translationX, .translationY:
            return .number(0)
        case .scale:
            return .number(1)
        case .scaleX, .scaleY:
            return .number(resolvedValue(.scale)?.number ?? 1)
        case .geometryTransform:
            return .values([
                .number(1), .number(0), .number(0),
                .number(1), .number(0), .number(0),
            ])
        default:
            return nil
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
        }
    }
}
