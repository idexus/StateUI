// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if MAUI

// A list that describes only the items in view: a composition compiled for the
// MAUI host alone, over a ScrollView holding an AbsoluteLayout whose length is
// computed from measured items, with nothing of its own on the wire.
// Design: docs/design/views/lists.md#itemsview-describes-only-the-items-in-view

/// A list that describes only the items in view.
///
///     @State private var chosen: String?
///
///     ItemsView(files, id: \.path) { file in
///         Label(file.name)
///     }
///     .selection($chosen)
///
/// The initializer is the item template, run for the items in view and six
/// slots either side: one view per item, the item its identity.
///
/// Bound it across the way it scrolls, as a scroller: a star row of a Grid or
/// a `.height`. In a bare stack it is given the length of all its items and
/// describes every one.
///
/// Its items are one length - the first one measured - unless
/// `.itemSizing(.individual)` says otherwise or `.itemSize(_:)` states one. An
/// item's root does not animate unless its author gives it a motion. An item
/// scrolled out of the window leaves the tree with its `@State`: what must
/// outlive the window belongs in the page, keyed by the item.
///
/// Write the list's own modifiers before the ones every view has.
public struct ItemsView<Items: RandomAccessCollection, Id: Hashable>: ContentView {
    // State first: boxes are adopted by path, and a header stored below may
    // carry boxes of its own.
    // Design: docs/design/views/composition.md#state-declared-first

    /// What the first placed item measured along the axis - the length every
    /// item is given where the author stated none. Zero until it settles.
    @State private var measuredItem = 0.0

    /// The same for a group's header, measured once for all of them.
    @State private var measuredHeader = 0.0

    /// And for a group's footer.
    @State private var measuredFooter = 0.0

    /// What each slot measured, by its identity rather than its position, which
    /// an insertion shifts - kept only where every item is measured.
    @State private var measuredItems: [String: Double] = [:]

    /// How wide the scroller is: width and height rather than along and across,
    /// since the axis can change while the frame does not.
    @State private var measuredWidth = 0.0

    /// And how tall.
    @State private var measuredHeight = 0.0

    /// Where the slots begin, past the list's header - what the offset is
    /// measured against, along the axis.
    @State private var itemsStart = 0.0

    /// The slot at the top of the viewport: the one structural decision a
    /// scroll makes, written by the engine only when it changes.
    @State private var firstShown = 0

    /// Where the list is scrolled to, where the author lent no state of their
    /// own.
    @State private var scrolled = Point.zero

    /// The screen, which the window is drawn against until the scroller reports
    /// its size: no list is longer than the window it is in.
    @Environment private var display: DeviceDisplay

    /// The groups and their templates, behind a class so the state walk stops
    /// before the items.
    private let source: Source

    /// The length the author stated for every item, rather than one measured.
    private var stated: Double?

    /// Whether one item is measured, or every item.
    private var sizing = ItemSizing.uniform

    /// Which way the items run.
    private var axis = ItemsOrientation.vertical

    /// What is drawn before every slot, scrolling with them.
    private var head: (any View)?

    /// And after every slot.
    private var foot: (any View)?

    /// What stands in while there is nothing to place.
    private var empty: (any View)?

    /// Where the choice lives, and how much of one it is.
    private var choice = Choice.none

    /// How many items after the last one in view still count as the end.
    private var endWithin = 0

    /// What runs when the user is that close to the end.
    private var endReached: EventHandler?

    /// The aim the scroller answers to.
    private var scroller: Aim<ScrollView>?

    /// Where the list is scrolled to, where the author lent a state.
    private var reports: Binding<Point>?

    /// How many slots either side of the visible ones are described, so an
    /// ordinary flick finds them already there.
    private static var margin: Int { 6 }

    /// What a slot is given while its kind has never been measured - one
    /// render's worth of arithmetic, replaced by the measurement it makes.
    static var provisional: Double { 44 }

    /// One item per element, the element its identity.
    ///
    ///     ItemsView(names) { name in
    ///         Label(name)
    ///     }
    ///
    /// - Parameters:
    ///   - items: What the list shows, one item each - distinct, since an
    ///     element is its item's identity.
    ///   - content: The item template, run for the items in view.
    public init(
        _ items: Items,
        content: @escaping (Items.Element) -> Element
    ) where Items.Element: Hashable, Id == Items.Element {
        self.init(items, id: \.self, content: content)
    }

    /// The same, for elements identified by the part `id` names - elements
    /// that are not `Hashable` whole, or that repeat.
    ///
    ///     ItemsView(files, id: \.path) { file in
    ///         Label(file.name)
    ///     }
    ///
    /// - Parameters:
    ///   - items: What the list shows, one item each.
    ///   - id: Which part of an element is its identity - distinct across the
    ///     list, stable while the element means the same item, and what a
    ///     selection is made of.
    ///   - content: The item template, run for the items in view.
    public init(
        _ items: Items,
        id: KeyPath<Items.Element, Id>,
        content: @escaping (Items.Element) -> Element
    ) {
        source = Source(groups: [ItemsGroup(items, id: id, content: content)])
    }

    /// Items under headers: the groups, each holding its items and what stands
    /// before and after them.
    ///
    ///     ItemsView(groups: shelves.map { shelf in
    ///         ItemsGroup(shelf.items) { Label($0) }
    ///             .id(shelf.name)
    ///             .header(Label(shelf.name))
    ///             .footer(Label("\(shelf.items.count) items"))
    ///     })
    ///
    /// A group's header and footer are SLOTS in the same run as the items, each
    /// kind measured once. An array rather than a builder closure: the groups
    /// are data, and a trailing closure would read as the item template.
    ///
    /// A selection names an item by its identity, so the identities of a
    /// selectable list are distinct across all its groups.
    ///
    /// - Parameter groups: The groups, in order.
    public init(groups: [ItemsGroup<Items, Id>]) {
        source = Source(groups: groups)
    }

    /// The length of every item along the axis, in device units - its height
    /// in a list that runs down, its width in one that runs across - instead
    /// of a length measured from the first item.
    ///
    ///     ItemsView(0..<1_000) { Label("Row \($0)") }
    ///         .itemSize(44)
    ///
    /// A stated length is known before anything is drawn, and it makes an
    /// item's offset arithmetic: item 500 starts at `500 * 44`. A group's
    /// header and footer are measured either way. Under
    /// `.itemSizing(.individual)` every item is still measured, and this is
    /// the length an item is given until it has been.
    ///
    /// A length at or below nought is refused with a complaint, and the first
    /// item is measured instead.
    ///
    /// - Parameter length: The length of an item, in device units.
    /// - Returns: The list, placing its items by that length.
    public func itemSize(_ length: Double) -> Self {
        guard length.isFinite, length > 0 else {
            complain("ItemsView.itemSize(_:) takes a length above nought, and was given "
                + "\(length). Measuring the first item instead.")
            return self
        }

        var copy = self
        copy.stated = length
        return copy
    }

    /// How much of the list is measured: one item answering for all of them,
    /// or every item on its own.
    ///
    ///     ItemsView(posts, id: \.number) { post in Label(post.text) }
    ///         .itemSizing(.individual)
    ///
    /// `.uniform`, the default, measures the first item and gives every other
    /// one its length - exact whenever the items are alike, and what makes a
    /// hundred thousand items cost what ten do. `.individual` measures every
    /// item, by its identity: each is its own length, and the run is worked
    /// out item by item. The items before the user have been measured, so
    /// nothing in view shifts as the rest of the run is.
    ///
    /// - Parameter value: How much to measure.
    /// - Returns: The list, measuring that way.
    public func itemSizing(_ value: ItemSizing) -> Self {
        var copy = self
        copy.sizing = value
        return copy
    }

    /// Which way the items run, and which way the user scrolls. Down unless
    /// this says otherwise.
    ///
    ///     ItemsView(1...200) { Label("Card \($0)") }
    ///         .orientation(.horizontal)
    ///         .itemSize(120)
    ///         .height(80)
    ///
    /// Across is the same arithmetic on the other axis: an item takes the
    /// list's whole height, as it takes the whole width going down, and a
    /// length stated or measured is a width. A list turned round measures its
    /// slots again, a height being no answer for a width.
    ///
    /// - Parameter value: Which way the items run.
    /// - Returns: The list, running that way.
    public func orientation(_ value: ItemsOrientation) -> Self {
        var copy = self
        copy.axis = value
        return copy
    }

    /// What is drawn before the first slot, scrolling with the list.
    ///
    /// - Parameter view: What stands before the items.
    /// - Returns: The list, headed by that view.
    public func header(_ view: any View) -> Self {
        var copy = self
        copy.head = view
        return copy
    }

    /// What is drawn after the last slot, scrolling with the list.
    ///
    /// - Parameter view: What stands after the items.
    /// - Returns: The list, followed by that view.
    public func footer(_ view: any View) -> Self {
        var copy = self
        copy.foot = view
        return copy
    }

    /// What the list shows while it has nothing to place - no item, and no
    /// group header or footer - between its own header and footer.
    ///
    /// A list with nothing in it has nothing to scroll, so what stands in for
    /// the items stands still.
    ///
    /// - Parameter view: What stands in for the items.
    /// - Returns: The list, showing that instead of nothing.
    public func emptyView(_ view: any View) -> Self {
        var copy = self
        copy.empty = view
        return copy
    }

    /// Which item is chosen: a tap on one writes its identity, and a tap on
    /// the chosen one clears it.
    ///
    ///     @State private var chosen: String?
    ///
    ///     ItemsView(names) { name in
    ///         Label(name)
    ///             .background(chosen == name ? .cornflowerBlue : .transparent)
    ///     }
    ///     .selection($chosen)
    ///
    /// The binding's type says how many may be chosen - one here, a `Set` below.
    /// A list lent no binding answers no tap, and what a chosen item looks like
    /// is the template's, reading the state the binding writes.
    ///
    /// - Parameter binding: Where the chosen item's identity is written.
    /// - Returns: The list, answering a tap on an item.
    public func selection(_ binding: Binding<Id?>) -> Self {
        var copy = self
        copy.choice = .one(binding)
        return copy
    }

    /// The same, for as many items as the user taps: each tap adds or
    /// removes that item's identity.
    ///
    ///     @State private var chosen: Set<Int> = []
    ///
    ///     ItemsView(0..<100) { number in
    ///         Label("Row \(number)")
    ///             .background(chosen.contains(number) ? .cornflowerBlue : .transparent)
    ///     }
    ///     .selection($chosen)
    ///
    /// - Parameter binding: Where the chosen items' identities are written.
    /// - Returns: The list, answering a tap on an item.
    public func selection(_ binding: Binding<Set<Id>>) -> Self {
        var copy = self
        copy.choice = .many(binding)
        return copy
    }

    /// Runs when the user is within `within` items of the end: the moment to
    /// append the next batch, so it is there when the user arrives.
    ///
    ///     @State private var count = 30
    ///
    ///     ItemsView(0..<count) { Label("Item \($0)") }
    ///         .onEndReached(within: 5) { count += 30 }
    ///
    /// Counted in items after the last one in view, so `0`, the default, runs
    /// as the last item comes into view; a batch shorter than the view asks
    /// again as the list grows. It runs more than once while the user stays
    /// near the end, so the handler guards on what it already asked for.
    ///
    /// - Parameters:
    ///   - within: How many items after the last one in view still count as
    ///     the end.
    ///   - handler: What to run there.
    /// - Returns: The list, asking for more at its end.
    public func onEndReached(within: Int = 0, _ handler: @escaping EventHandler) -> Self {
        var copy = self
        copy.endWithin = max(0, within)
        copy.endReached = handler
        return copy
    }

    /// The scroller this list is, for an act aimed at it.
    ///
    ///     @Aim(ScrollView.self) private var list
    ///
    ///     ItemsView(names) { Label($0) }.aim(list)
    ///
    /// Moving it is not an act but a write to the `scrollOffset($:)` state.
    ///
    /// - Parameter aim: The aim the list's scroller answers to.
    /// - Returns: The list, whose scroller answers there.
    public func aim(_ aim: Aim<ScrollView>) -> Self {
        var copy = self
        copy.scroller = aim
        return copy
    }

    /// Where the list is scrolled to, in device units from the start of its
    /// run, both ways: the host writes the user's scrolling into it, and a
    /// value written here moves the list.
    ///
    ///     @State private var offset = Point.zero
    ///
    ///     ItemsView(0..<1_000) { Label("Row \($0)") }
    ///         .itemSize(44)
    ///         .scrollOffset($offset)
    ///
    ///     Button("Row 500").onClicked {
    ///         try await $offset.journey.move(to: Point(0, 500 * 44), .eased(300, .cubicOut))
    ///     }
    ///
    /// A plain write jumps, and `$offset.journey.move(to:_:)` with a motion
    /// animates; an offset past the end is held to the end. The list itself
    /// renders only when the slot at the top changes.
    ///
    /// - Parameter state: The state the offset is carried on.
    /// - Returns: The list, moving with that state and reporting into it.
    public func scrollOffset(_ state: Binding<Point>) -> Self {
        var copy = self
        copy.reports = state
        return copy
    }

    /// The scroller, the slots placed inside it, and what decides which slots
    /// those are.
    public var content: any View {
        let plan = plan
        let window = window(of: plan)
        let vertical = axis == .vertical
        let offset = reports ?? $scrolled
        let ask = asking(plan)

        var list = ScrollView {
            // One branch whichever way a bare list runs, so turning it round
            // does not build every slot again.
            if head == nil && foot == nil {
                run(window, of: plan)
            } else if vertical {
                if let head { head }

                run(window, of: plan)

                if let foot { foot }
            } else {
                // A scroller stacks several children DOWNWARDS, so a list
                // running across puts its three parts in a row of their own.
                HStack {
                    if let head { head }

                    run(window, of: plan)

                    if let foot { foot }
                }
                .spacing(0)
            }
        }
        // A list with nothing in it has nothing to scroll, and saying so is
        // what bounds whatever stands in for the items.
        .orientation(plan.slots == 0 ? .neither : (vertical ? .vertical : .horizontal))
        // The list's own numbers arrive: each answers a measurement.
        .motion(.none)
        .scrollOffset(offset)
        .aimed(at: scroller)

        let widths = _measuredWidth
        let heights = _measuredHeight
        let lengths = [_measuredItem, _measuredHeader, _measuredFooter]
        let each = _measuredItems
        let firsts = _firstShown
        let starts = _itemsStart

        list = list
            // How much is in view, and whether the end is now near.
            .onFrameChanged { frame in
                if frame.width != widths.wrappedValue { widths.wrappedValue = frame.width }
                if frame.height != heights.wrappedValue { heights.wrappedValue = frame.height }

                try await ask?()
            }
            // A list turned round forgets every length it measured, headers and
            // footers included: a length along one axis is none along the other.
            .onChanged(axis) {
                for length in lengths where length.wrappedValue != 0 {
                    length.wrappedValue = 0
                }

                if !each.wrappedValue.isEmpty { each.wrappedValue = [:] }
            }
            // Which slot is at the top, from where the scroller is, written only
            // when it changes: one render per item crossed, none per frame.
            // Design: docs/design/views/lists.md#two-paths
            .engine(following: offset, $itemsStart) { _ in
                guard plan.settled, plan.slots > 0 else { return }

                let at = offset.journey.value
                let along = (vertical ? at.y : at.x) - starts.wrappedValue

                // A reading from outside is not a number until it is checked.
                guard along.isFinite else { return }

                let top = plan.slot(at: along)

                if top != firsts.wrappedValue { firsts.wrappedValue = top }
            }

        if let ask {
            // Asked here, on the description path: an engine awaits nothing.
            list = list.onChanged(firstShown) { try await ask() }
        }

        return list
    }

    /// The items, or whatever stands in for them where there are none.
    @ViewBuilder
    private func run(_ window: [Int], of plan: Plan) -> [Element] {
        if plan.slots == 0 {
            if let empty { empty }
        } else {
            placed(window, of: plan)
        }
    }

    /// The slots of the window, each where the arithmetic puts it, in a layout
    /// whose length is stated so the scroller knows how far it goes.
    private func placed(_ window: [Int], of plan: Plan) -> Element {
        let starts = _itemsStart
        let ask = asking(plan)
        let vertical = axis == .vertical
        let across = vertical ? measuredWidth : measuredHeight

        var layout = AbsoluteLayout {
            ForEach(slots(window, of: plan), id: \.identity) { slot in
                described(slot, across: across, vertical: vertical)
            }
        }
        // The run's length and every placement answer a measurement.
        .motion(.none)
        // A scroll builds one item and drops one of the same shape: a pool.
        .recycling()
        // Pinned to the start along the axis, so a short run is not centred;
        // across it, it fills.
        .verticalAlignment(vertical ? .start : .fill)
        .horizontalAlignment(vertical ? .fill : .start)

        // The run's length, once every kind is measured.
        if plan.settled {
            layout = vertical ? layout.height(plan.extent) : layout.width(plan.extent)
        }

        // A scroller measuring its content sideways offers it no height, so a
        // list running across is told its own: the scroller's measured height.
        if !vertical, across > 0 {
            layout = layout.height(across)
        }

        return layout.onFrameChanged { frame in
            let start = vertical ? frame.y : frame.x

            if start != starts.wrappedValue { starts.wrappedValue = start }

            // The run grows, so the end may now be near with no scroll.
            try await ask?()
        }
    }

    /// Every slot of the window, with where it sits and who it is.
    private func slots(_ window: [Int], of plan: Plan) -> [Placed] {
        // Slots measure themselves while a kind is unmeasured, and always where
        // every item is its own length.
        let measuring: Set<Int> = sizing == .individual || !plan.settled ? Set(window) : []

        return window.compactMap { (index: Int) -> Placed? in
            let slot = plan.slot(index)
            let group = source.groups[slot.group]
            let start = plan.start(of: index)

            switch slot.kind {
            case .header, .footer:
                guard let view = slot.kind == .header ? group.head : group.foot else { return nil }

                return Placed(
                    identity: identity(group: slot.group, kind: slot.kind, offset: 0),
                    view: view,
                    chooses: nil,
                    start: start,
                    length: plan.length(of: slot.kind),
                    measures: measuring.contains(index) ? slot.kind : nil)

            case .item:
                let item = group.item(at: slot.offset)

                return Placed(
                    identity: identity(group: slot.group, kind: .item, offset: slot.offset),
                    view: group.template(item),
                    chooses: item[keyPath: group.path],
                    start: start,
                    length: plan.length(of: .item),
                    measures: measuring.contains(index) ? .item : nil)
            }
        }
    }

    /// One slot: the author's view, placed, measuring itself where it has to,
    /// and answering a tap where the list is selectable.
    private func described(_ slot: Placed, across: Double, vertical: Bool) -> Element {
        // A slot that measures itself is laid out at its own length.
        let length = slot.measures == nil ? slot.length : AbsoluteLayout.autoSize

        // Across the axis, as long as the measured scroller.
        let breadth = across > 0 ? across : AbsoluteLayout.autoSize

        var view = ModifiedContent(node: slot.view.body)
            .absoluteLayoutBounds(vertical
                ? Rect(0, slot.start, breadth, length)
                : Rect(slot.start, 0, length, breadth))
            // An item arrives unless its author gave its root a motion: the list
            // hands controls round, and a recycled item would animate.
            // Design: docs/design/views/lists.md#items-arrive
            .modified { node in
                // `Motion.none` spelled out: a bare `.none` is `Optional.none`.
                if node.motion == nil { node.motion = MotionPlan(base: Motion.none) }
            }

        if let kind = slot.measures {
            let lengths = box(of: kind)
            let all = _measuredItems
            let each = sizing == .individual
            let name = slot.identity

            view = view.onFrameChanged { frame in
                let measured = vertical ? frame.height : frame.width

                guard measured > 0 else { return }

                // The kind's length, whatever the sizing, settles the arithmetic.
                if lengths.wrappedValue <= 0 { lengths.wrappedValue = measured }

                if each, all.wrappedValue[name] != measured {
                    all.wrappedValue[name] = measured
                }
            }
        }

        guard let chooses = slot.chooses, !choice.isNone else { return view }

        // A local rather than `self`, which holds a class.
        let choice = choice

        return view.onTapped { choice.choose(chooses) }
    }

    /// Whether the user is within `endWithin` items of the end, as one closure
    /// every place it can become true asks - built of locals, not `self`.
    private func asking(_ plan: Plan) -> EventHandler? {
        guard let endReached else { return nil }

        let within = endWithin
        let firsts = _firstShown
        let widths = _measuredWidth
        let heights = _measuredHeight
        let vertical = axis == .vertical

        return {
            guard plan.settled, plan.slots > 0 else { return }

            let viewport = vertical ? heights.wrappedValue : widths.wrappedValue

            // Until the viewport is measured the user is nowhere yet.
            guard viewport > 0 else { return }

            let top = plan.clamped(firsts.wrappedValue)
            let last = plan.clamped(top + plan.fits(in: viewport) - 1)

            guard plan.items(after: last) <= within else { return }

            try await endReached()
        }
    }

    /// Which slots are described: the one at the top, the ones that fit after
    /// it and a margin either side - or, while a kind is unmeasured, the first
    /// slot of each such kind, wherever it falls.
    private func window(of plan: Plan) -> [Int] {
        guard plan.slots > 0 else { return [] }

        guard plan.settled else {
            return [Kind.header, .item, .footer]
                .filter { plan.needs($0) }
                .compactMap { plan.first($0) }
                .sorted()
        }

        let measured = axis == .vertical ? measuredHeight : measuredWidth

        // A viewport as long as the whole run is an unbounded list: said, not
        // refused, and only where the run is longer than a screen.
        if measured >= plan.extent, plan.extent > screenful {
            complain("an ItemsView measured a viewport as long as its whole run, so "
                + "every item of it is described and nothing is left to scroll. A "
                + "list is as long as it is GIVEN room to be - inside a stack that is "
                + "its own content, which is the usual cause. A grid row, or a stated "
                + "height, bounds it.")
        }

        let fits = plan.fits(in: measured > 0 ? measured : screenful)
        let top = plan.clamped(firstShown)
        let first = max(0, top - Self.margin)
        let last = min(plan.slots, top + fits + Self.margin)

        return Array(first..<max(first + 1, last))
    }

    /// Where every group starts, in slots, in items and along the axis - worked
    /// out once per render, over the GROUPS rather than the items.
    private var plan: Plan {
        let item = stated ?? measuredItem

        return Plan(
            shapes: source.groups.map {
                GroupShape(header: $0.head != nil, items: $0.items.count, footer: $0.foot != nil)
            },
            item: item,
            header: measuredHeader,
            footer: measuredFooter,
            lengths: sizing == .individual ? lengths(guess(item)) : nil)
    }

    /// How long the screen is along the axis, in device units: how much can be
    /// in view until the scroller reports, never short.
    private var screenful: Double {
        let side = axis == .vertical ? display.height : display.width

        return display.density > 0 && side > 0 ? side / display.density : 1_000
    }

    /// The length of every slot, in order, for a list measuring every item: a
    /// slot never in view is worth the estimate.
    private func lengths(_ estimate: Double) -> [Double] {
        var all: [Double] = []
        all.reserveCapacity(source.groups.count * 8)

        for (index, group) in source.groups.enumerated() {
            if group.head != nil {
                all.append(measured(index, .header, 0) ?? guess(measuredHeader))
            }

            for offset in 0..<group.items.count {
                all.append(measured(index, .item, offset) ?? estimate)
            }

            if group.foot != nil {
                all.append(measured(index, .footer, 0) ?? guess(measuredFooter))
            }
        }

        return all
    }

    /// What one slot measured, or nothing where it has never been in view.
    private func measured(_ group: Int, _ kind: Kind, _ offset: Int) -> Double? {
        measuredItems[identity(group: group, kind: kind, offset: offset)]
    }

    /// A measurement, or the standing guess while there is none.
    private func guess(_ value: Double) -> Double {
        value > 0 ? value : Self.provisional
    }

    /// What a slot is called: the one answer the window and the plan both file
    /// under.
    private func identity(group: Int, kind: Kind, offset: Int) -> String {
        let shape = source.groups[group]

        if kind != .item {
            return "\(shape.name ?? "\(group)")/\(kind.suffix)"
        }

        let own = String(describing: shape.item(at: offset)[keyPath: shape.path])

        // Under its group's name, or its position, so two groups may hold
        // equal items; a list of one group prefixes nothing.
        let under = source.groups.count > 1 ? (shape.name ?? "\(group)") : shape.name

        return under.map { "\($0)/\(own)" } ?? own
    }

    /// Where a measured length is kept, by the kind that measured it.
    private func box(of kind: Kind) -> State<Double> {
        switch kind {
        case .header: return _measuredHeader
        case .item: return _measuredItem
        case .footer: return _measuredFooter
        }
    }

    /// One slot of the window, ready to be described.
    private struct Placed {
        /// Who it is, in the id namespace the author writes in.
        let identity: String

        /// What it shows.
        let view: Element

        /// What a tap on it chooses - an item's identity, and nothing for a
        /// header or a footer.
        let chooses: Id?

        /// Where it starts along the axis, in device units.
        let start: Double

        /// How long it is along the axis.
        let length: Double

        /// Which kind's length it measures, where it measures one.
        let measures: Kind?
    }

    /// What the list shows, behind a class so the state walk stops before it.
    private final class Source {
        /// Every group, with its items and its templates.
        let groups: [ItemsGroup<Items, Id>]

        /// What the initializers were handed.
        init(groups: [ItemsGroup<Items, Id>]) {
            self.groups = groups
        }
    }

    /// Where a choice lives - and the type of the binding is how much of one.
    private enum Choice {
        /// Nobody lent a binding, so the items are not selectable.
        case none

        /// One item at a time, or none.
        case one(Binding<Id?>)

        /// As many as are tapped.
        case many(Binding<Set<Id>>)

        /// Whether this list is selectable at all.
        var isNone: Bool {
            if case .none = self { return true }
            return false
        }

        /// What a tap on an item means: a tap on the chosen item clears the
        /// choice, and among many, a tap moves that item alone.
        func choose(_ id: Id) {
            switch self {
            case .none:
                break

            case .one(let binding):
                binding.wrappedValue = binding.wrappedValue == id ? nil : id

            case .many(let binding):
                var chosen = binding.wrappedValue

                if chosen.remove(id) == nil {
                    chosen.insert(id)
                }

                binding.wrappedValue = chosen
            }
        }
    }
}

#endif
