// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One element of the mounted tree: the runtime's live instance of a described node.
/// Design: docs/design/host/tree.md#the-mounted-tree
@_spi(Host) @MainActor public final class MountedElement {
    /// The element's key.
    public let id: ElementId

    /// The element's node type.
    public let type: NodeType

    /// The element's instance number, which its animations are filed under.
    public let mount: UInt64

    /// The element that holds this one.
    public private(set) weak var parent: MountedElement?

    /// The elements this one holds, in order - a grid's and a ZStack's in the order they are drawn, by
    /// `zIndex`, ties in the order written.
    public private(set) var children: [MountedElement] = []

    /// Each child's place in the order the last arrangement wrote them.
    private var writingOrder: [ElementId: Int] = [:]

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

    /// The frame report this element last said, which a report the same says again to nobody.
    var reportedFrame: [Double] = []

    /// Where the states a press dragged carries stood as it began.
    var dragStart = Point(x: 0, y: 0)

    /// The toolkit's half of the element.
    public private(set) var native: (any NativeElement)!

    private weak var tree: MountedTree?
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

        native.willApply()
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

        switch patch.children {
        case .unchanged:
            break

        case .arranged(let childPatches):
            writingOrder = Dictionary(childPatches.enumerated().map { ($1.id, $0) }) { first, _ in first }
            arrange(childPatches, tree: tree)

        case .changed(let childPatches):
            for childPatch in childPatches {
                // A new child arrives only in an arranged list; a sparse list naming a stranger drifted.
                guard let index = children.firstIndex(where: { $0.id == childPatch.id }) else {
                    tree.intake.drifted("a patch names child '\(childPatch.id)' that '\(id)' does not have")
                    continue
                }
                let child = children[index]

                if child.type == childPatch.type, !childPatch.replace {
                    child.apply(childPatch)
                } else if childPatch.replace {
                    child.leave()
                    children[index] = MountedElement(childPatch, tree: tree, parent: self)
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
        if changed.contains(.layoutDirection) { directionTurned(arrangingItself: false) }
        framesRead = driven[.frame] != nil || events[.frameChanged] != nil
            || children.contains { $0.framesRead }
        native.applied(changed: changed, wasDescribed: described)
        described = true
    }

    /// Reconciles a complete child arrangement by key.
    private func arrange(_ patches: [HostPatch], tree: MountedTree) {
        let before = children
        let previous = Dictionary(uniqueKeysWithValues: children.map { ($0.id, $0) })

        children = patches.map { patch in
            if let child = previous[patch.id], child.type == patch.type, !patch.replace {
                child.parent = self
                child.apply(patch)
                return child
            }

            return MountedElement(patch, tree: tree, parent: self)
        }
        leave(before)
    }

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

    /// The direction this element lays out in turned: it and every layout under it that inherits the direction
    /// arrange their children again, the element itself when its patch will not.
    /// Design: docs/design/host/layout.md#right-to-left
    func directionTurned(arrangingItself: Bool) {
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
        let staying = Set(children.map(ObjectIdentifier.init))
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
        native.leave()
        for child in children { child.leave() }
    }

    /// The first element of `type` in this subtree, this one first.
    public func first(type sought: NodeType) -> MountedElement? {
        if type == sought { return self }

        for child in children {
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

    /// The first element with key `sought` in this subtree, this one first.
    public func first(id sought: ElementId) -> MountedElement? {
        if id == sought { return self }

        for child in children {
            if let found = child.first(id: sought) { return found }
        }

        return nil
    }

    /// Every element with key `sought` in this subtree.
    public func all(id sought: ElementId) -> [MountedElement] {
        var found = id == sought ? [self] : []
        for child in children {
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

        for child in children {
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
        for child in children { child.forgetForTesting(where: matches) }
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

        let own = changed.isEmpty ? FrameImpact.none : native.presentFrame(changed)
        var descendants = FrameImpact.none

        for child in children {
            descendants = descendants.union(child.applyFrame(states: valuesByState, properties: propertiesByMount))
        }

        // A child's place is its parent's business; an element with no view passes it up.
        let restacked = restack()
        if own.content || descendants.arrangement || restacked { native.arrangeChildren() }
        guard native.presentsView else { return own.union(descendants) }
        descendants.arrangement = false
        return own.union(descendants)
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

    /// The handler of `event`, when the tree listens to it.
    public func handler(_ event: Event) -> Int32? { events[event] }

    /// The direction this element lays out in: its own, or where it inherits, its parent's - the
    /// language's at the root, as the host reported the locale.
    /// Design: docs/design/host/layout.md#right-to-left
    public var layoutDirection: LayoutDirection {
        switch value(.layoutDirection)?.enumeration.flatMap(LayoutDirection.init(rawValue:)) {
        case .leftToRight?: return .leftToRight
        case .rightToLeft?: return .rightToLeft
        default: return parent?.layoutDirection ?? StandardEnvironment.locale.layoutDirection
        }
    }

    /// What a layout reads of this element as its child.
    /// Design: docs/design/host/layout.md#the-layout-arithmetic
    public var layoutValues: LayoutValues {
        var values = LayoutValues()
        if let sides = value(.margin)?.numbers, sides.count >= 4 {
            values.margin = Insets(sides[0], sides[1], sides[2], sides[3])
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
            return value(property, lanes: lanes)

        case (.property, let carried):
            let presented = tree?.presentedValue(for: binding, from: carried) ?? carried
            guard let journey = StateUIHost.journey(from: presented) else {
                return properties[property]
            }
            return value(property, lanes: journey.value)

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
        case .strokeWidth:
            return .number(1)
        case .strokeDashOffset, .x1, .y1, .x2, .y2:
            return .number(0)
        case .strokeMiterLimit:
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
        case .renderTransform:
            return .values([
                .number(1), .number(0), .number(0),
                .number(1), .number(0), .number(0),
            ])
        default:
            return nil
        }
    }

    /// A bound state's lanes as the value `property` carries.
    private func value(_ property: Prop, lanes: [Double]) -> HostValue? {
        guard !lanes.isEmpty else { return nil }

        if Self.colorProperties.contains(property), lanes.count >= 4 {
            func channel(_ value: Double) -> UInt8 {
                UInt8(min(max((value * 255).rounded(), 0), 255))
            }

            return .color(
                red: channel(lanes[0]),
                green: channel(lanes[1]),
                blue: channel(lanes[2]),
                alpha: channel(lanes[3]))
        }

        if Self.booleanProperties.contains(property) {
            return .bool(lanes[0] != 0)
        }

        if Self.enumerationProperties.contains(property) {
            return .enumeration(Int32(lanes[0].rounded()))
        }

        return lanes.count == 1 ? .number(lanes[0]) : .numbers(lanes)
    }

    private static let colorProperties: Set<Prop> = [
        .background, .barBackgroundColor, .barForegroundColor, .color,
        .indicatorColor, .placeholderColor, .selectedIndicatorColor, .textColor, .tint,
    ]

    private static let booleanProperties: Set<Prop> = [
        .allowDrop, .hidesWhenInactive, .canDrag, .floatsOnTop, .growsWithText, .ignoresInput,
        .isAnimating, .clipsContent, .isDestructive,
        .isEnabled, .isMaximizable, .isMinimizable, .isTranslucent,
        .isOpen, .isPassword, .isSidebarVisible, .isReadOnly,
        .isRunning, .isScrollEnabled,
        .showsUserLocation, .isSpellCheckEnabled, .isTextPredictionEnabled,
        .isOn, .isTrafficEnabled, .isVisible, .isZoomEnabled, .letsInputThrough,
        .showsClearButton,
    ]

    private static let enumerationProperties: Set<Prop> = [
        .aspect, .layoutDirection, .fontAttributes,
        .horizontalAlignment, .horizontalScrollBarVisibility,
        .horizontalTextAlignment, .inputPurpose,
        .lineBreak, .orientation, .returnKey, .textDecorations, .textCase,
        .verticalAlignment, .verticalScrollBarVisibility, .verticalTextAlignment,
    ]
}
