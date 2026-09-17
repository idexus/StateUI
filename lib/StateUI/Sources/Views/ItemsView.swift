// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if MAUI

// A LIST THAT DESCRIBES ONLY THE ITEMS IN VIEW.
//
//     ItemsView(files, id: \.path) { file in
//         Label(file.name)
//     }
//     .selection($chosen)
//
// Compiled for the MAUI host alone: a StateUI composition over controls that
// already cross the boundary, and nothing of its own on the wire - no node
// type, no host arm, no fixture.
//
// WHAT IT IS MADE OF. A ScrollView holding an AbsoluteLayout whose length is
// computed, and the slots in view placed in it by arithmetic. The length is the
// count times one measured item, so the scroller knows how far it goes before a
// single item is described; the scroll position, the measured viewport and that
// one length say which slots are in view. Those, and a margin either side, are
// the only ones described, built and sent.
//
// TWO PATHS, EACH FOR WHAT IT IS FOR. The offset is host-carried state: the
// host writes the reader's scrolling into it on its own frames, and nothing is
// described for it. An engine following it works out which slot is at the top
// and writes that into ordinary state only when it changes - so a fling
// renders once per item crossed and never once per frame. WHICH items exist is
// a structural decision, and the body reads it.
//
// GROUPS ARE THE SAME ARITHMETIC, one level up. A grouped list is a run of
// SLOTS - a group's header, its items, its footer, the next header - and each
// kind is measured once, so where any slot sits is a sum over the groups before
// it, worked out once per render over the groups rather than the items.
//
// WHAT IT COSTS. An item that scrolls out of the window leaves the tree and
// takes its own `@State` with it; the host keeps its control for the next item
// of the same shape. What must outlive the window belongs in the page, keyed by
// the item.

/// How much of an `ItemsView` is measured to know where each item goes.
///
/// The list works out where a slot sits by arithmetic rather than by laying
/// every item out, so how much of it has to be measured is what decides what a
/// long list costs.
public enum ItemSizing: Sendable {
    /// One item is measured and every other one is given its length. The
    /// default.
    ///
    /// Where a slot sits is then one multiplication, so a hundred thousand
    /// items cost what ten do. Exact whenever the items are alike.
    case uniform

    /// Every item is measured, and each one is its own length, filed under its
    /// identity.
    ///
    /// For a feed whose posts are a line or a paragraph, a chat, a run of tags.
    /// Every item is walked to work out where the next one goes, so it suits
    /// tens or hundreds of items. An item that has never been in view has never
    /// been measured, and the length of the run is an estimate until it has.
    case individual
}

/// Which way an `ItemsView` runs, and which way the reader scrolls it.
public enum ItemsOrientation: Sendable {
    /// Down. The default.
    case vertical

    /// Across.
    case horizontal
}

/// A list that describes only the items in view.
///
///     @State private var chosen: String?
///
///     ItemsView(files, id: \.path) { file in
///         Label(file.name)
///     }
///     .selection($chosen)
///
/// The initializer is the item template, run for the items in view: one view
/// per item, the item its identity. However long the collection, what is
/// described is the items in view and a margin of six slots either side.
///
/// **It is bounded across the way it scrolls**, as a scroller is: a star row of
/// a Grid or a `.height` for a list that runs down, a `.height` for one that
/// runs across. In a bare stack a list running down is given the length of all
/// its items, describes every one of them, and has nothing left to scroll.
///
/// **Its items are one length unless `.itemSizing(.individual)` says
/// otherwise**: the first item placed is measured and every item is given its
/// length, which is what lets the list know how long it is without describing
/// anything. `.itemSize(_:)` states the length instead.
///
/// **An item arrives, it does not travel.** The list places its items by
/// arithmetic and hands their controls round, so an item's root is given
/// `Motion.none` unless its author wrote a law there. A law written inside an
/// item travels as its author says.
///
/// **An item scrolled out of the window leaves the tree**, and its own
/// `@State` goes with it. What must outlive the window - a half-typed edit,
/// whether an item is expanded - belongs in the page, keyed by the item.
///
/// Write the list's own modifiers before the ones every view has: `.height`
/// and its kind give back the wrapper every composed view's modifiers give
/// back.
public struct ItemsView<Items: RandomAccessCollection, Id: Hashable>: ContentView {
    // The state is declared FIRST: a box is adopted by its PATH, the stored
    // property's own name at every level (Core/Stateful.swift), and a header
    // stored below may be a composed view carrying boxes of its own.

    /// What the first placed item measured along the axis - the length every
    /// item is given where the author stated none. Zero until it settles.
    @State private var measuredItem = 0.0

    /// The same for a group's header, measured once and answering for all of
    /// them.
    @State private var measuredHeader = 0.0

    /// And for a group's footer.
    @State private var measuredFooter = 0.0

    /// What each slot measured, by its identity - filled only where every item
    /// is measured.
    ///
    /// BY IDENTITY, never by position: an item inserted at the top would
    /// otherwise hand every item below it its neighbour's length. A slot that
    /// has never been in view is not in here at all.
    @State private var measuredItems: [String: Double] = [:]

    /// How wide the scroller is, as layout settled it.
    ///
    /// Kept as a width and a height rather than along and across the axis,
    /// because the axis can change while the frame does not: a list turned to
    /// run across is the same rectangle, and would wait for a report that
    /// never comes.
    @State private var measuredWidth = 0.0

    /// And how tall.
    @State private var measuredHeight = 0.0

    /// Where the slots begin, past the list's header - what the offset is
    /// measured against, along the axis.
    @State private var itemsStart = 0.0

    /// The slot at the top of the viewport, which the window is drawn around.
    ///
    /// The one structural decision a scroll makes: written by the engine only
    /// when it changes, and read by the body.
    @State private var firstShown = 0

    /// Where the list is scrolled to, where the author lent no state of their
    /// own.
    @State private var scrolled = Point.zero

    /// The screen, which the window is drawn against while the scroller has
    /// not reported its own size. No list is longer than the window it is in,
    /// so a screenful of slots is never short - and the scroller's report can
    /// arrive after the slots are placed.
    @Environment private var display: DeviceDisplay

    /// The groups and their templates, held BY REFERENCE, which is what stops
    /// the state walk here: reflecting a hundred thousand items on every build
    /// is what this list exists not to do, and the walk stops at any class.
    /// See Core/Stateful.swift.
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

    /// What runs when the reader is that close to the end.
    private var endReached: EventHandler?

    /// The aim the scroller answers to.
    private var scroller: Aim<ScrollView>?

    /// Where the list is scrolled to, where the author lent a state.
    private var reports: Binding<Point>?

    /// How many slots either side of the visible ones are described anyway,
    /// so an ordinary flick finds them already there. A slot is cheap here and
    /// a blank one is not, which is what decides the number.
    private static var margin: Int { 6 }

    /// What a slot is given while its kind has never been measured - one
    /// render's worth of arithmetic, replaced by the measurement it makes.
    private static var provisional: Double { 44 }

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
    /// A length that is not above nought is no length: the list says so once
    /// and measures its first item instead.
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
    /// out item by item. The items before the reader have been measured, so
    /// nothing in view shifts as the rest of the run is.
    ///
    /// - Parameter value: How much to measure.
    /// - Returns: The list, measuring that way.
    public func itemSizing(_ value: ItemSizing) -> Self {
        var copy = self
        copy.sizing = value
        return copy
    }

    /// Which way the items run, and which way the reader scrolls. Down unless
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
    /// The binding's TYPE says how many items may be chosen - one here, a
    /// `Set` in the form below - so there is no mode beside it to disagree
    /// with. A list nobody lends a binding to answers no tap at all.
    ///
    /// What a chosen item looks like is the template's: it reads the state the
    /// binding writes.
    ///
    /// - Parameter binding: Where the chosen item's identity is written.
    /// - Returns: The list, answering a tap on an item.
    public func selection(_ binding: Binding<Id?>) -> Self {
        var copy = self
        copy.choice = .one(binding)
        return copy
    }

    /// The same, for as many items as the reader taps: each tap adds or
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

    /// Runs when the reader is within `within` items of the end: the moment to
    /// append the next batch, so it is there when the reader arrives.
    ///
    ///     @State private var count = 30
    ///
    ///     ItemsView(0..<count) { Label("Item \($0)") }
    ///         .onEndReached(within: 5) { count += 30 }
    ///
    /// Counted in ITEMS after the last one in view - a group's header and
    /// footer are no items - so `0`, the default, runs as the last item comes
    /// into view. It is asked when the slot at the top changes, and when the
    /// list or its run is measured: a batch shorter than the view leaves
    /// nothing to scroll, and the list asks again as it grows, until it
    /// outgrows the view.
    ///
    /// It runs more than once while the reader stays near the end, so the
    /// handler guards on what it has already asked for. A list without this
    /// never asks.
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
    /// An `Aim<ScrollView>`, because a scroller is what the list is from the
    /// outside. Moving it is not an act: it is a write to `scrollOffset($:)`.
    ///
    /// - Parameter aim: The aim the list's scroller answers to.
    /// - Returns: The list, whose scroller answers there.
    public func aim(_ aim: Aim<ScrollView>) -> Self {
        var copy = self
        copy.scroller = aim
        return copy
    }

    /// Where the list is scrolled to, in device units from the start of its
    /// run - both ways. The host writes the reader's scrolling into it on its
    /// own frames, and a value written here moves the list.
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
    /// The list's own arithmetic arrives rather than travels - its scroller
    /// carries `Motion.none` - so a write with no law of its own is a jump,
    /// and `$offset.journey.move(to:_:)` with a law glides. An offset past the
    /// end is held to the end.
    ///
    /// Handing `$offset` over reads nothing, so what the offset costs is
    /// decided by whoever reads it; the list itself follows it with an engine
    /// and renders only when the slot at the top changes.
    ///
    /// - Parameter state: The state the offset is walked on.
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
            // ONE BRANCH WHICHEVER WAY AN UNFURNISHED LIST RUNS: two branches
            // are two elements even where they build the same control, so a
            // list turned round would build every slot in view again.
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
        // THE LIST'S OWN NUMBERS ARRIVE, they do not travel: every length it
        // states answers a measurement, and an offset written with no law of
        // its own is a place, not a trip.
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
            // HOW MUCH IS IN VIEW - and a moment "is the reader near the end"
            // can become true, for a list already showing its end.
            .onFrameChanged { frame in
                if frame.width != widths.wrappedValue { widths.wrappedValue = frame.width }
                if frame.height != heights.wrappedValue { heights.wrappedValue = frame.height }

                try await ask?()
            }
            // A LENGTH MEASURED ALONG ONE AXIS IS NO LENGTH ALONG THE OTHER, so
            // a list turned round forgets every one it measured and measures
            // its slots again - a group's header and footer included, which are
            // measured whether or not the items' length is stated.
            .onChanged(axis) {
                for length in lengths where length.wrappedValue != 0 {
                    length.wrappedValue = 0
                }

                if !each.wrappedValue.isEmpty { each.wrappedValue = [:] }
            }
            // WHICH SLOT IS AT THE TOP, worked out on the host's own frames from
            // where the scroller IS, and written only when it changes: a flick
            // crossing four items renders four times, and a frame crossing none
            // renders nothing. It also runs once after every render, so a run
            // measured anew puts the window where the offset says.
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
            // THE SLOT AT THE TOP CHANGED, which is how a scroll brings the
            // reader near the end. Asked here, on the description path: an
            // engine runs inside a frame and awaits nothing.
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

    /// The slots of the window, each where the arithmetic puts it.
    ///
    /// The layout's own length is stated - the sum over the groups - so the
    /// scroller knows how far it goes before a single item is described, and
    /// every slot is placed by its number rather than by what stands before it.
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
        // The items are what a pool is for: a scroll of one item builds one and
        // drops one, and the two are the same shape whenever the template wrote
        // the same modifiers for both.
        .recycling()
        // THE RUN STARTS WHERE THE SCROLLER DOES. A view stating a length of its
        // own is centred in whatever room is left over, so a run shorter than
        // its box would stand in the middle of it. Along the axis it is pinned;
        // across it, it fills.
        .verticalAlignment(vertical ? .start : .fill)
        .horizontalAlignment(vertical ? .fill : .start)

        // The run's own length, once every kind it has is measured. Until then
        // the slots placed measure themselves, and the layout is as long as
        // they are.
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

            // This frame is the RUN's, so it changes as the list grows - the
            // moment "is the reader near the end" becomes true with no scroll
            // to say so.
            try await ask?()
        }
    }

    /// Every slot of the window, with where it sits and who it is.
    ///
    /// Each position costs a binary search over the GROUPS: a flat list has
    /// one group, and a hundred groups are seven comparisons.
    private func slots(_ window: [Int], of plan: Plan) -> [Placed] {
        // While a kind has never been measured, every slot placed measures
        // itself - the window IS the first slot of each such kind - and it
        // carries the only frame subscription there will be. Where every item
        // is measured, every slot described keeps its subscription: each is
        // its own length, and a slot whose content changes is a new one.
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
        // A slot that measures itself is laid out at its OWN length, which is
        // the whole of what "every item is its own length" means.
        let length = slot.measures == nil ? slot.length : AbsoluteLayout.autoSize

        // Across the axis a slot is as long as the scroller, once it has been
        // measured; until then it measures itself there too.
        let breadth = across > 0 ? across : AbsoluteLayout.autoSize

        var view = ModifiedContent(node: slot.view.body)
            .absoluteLayoutBounds(vertical
                ? Rect(0, slot.start, breadth, length)
                : Rect(slot.start, 0, length, breadth))
            // AN ITEM ARRIVES, IT DOES NOT TRAVEL, unless its author says
            // otherwise on the item's root. The list hands its controls round:
            // the item scrolling into view is very often the one that just left
            // the other end, wearing another item's words and widths, so a law
            // on its root would walk its insides across the screen while the
            // reader scrolls. A law is per node and never inherited, so what
            // the author wrote INSIDE an item still travels.
            .modified { node in
                // `Motion.none` spelled out: `base` is an optional, and a bare
                // `.none` there is `Optional.none` - a plan stating no law.
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

                // The kind's own length is taken whatever the sizing: it is
                // what says the arithmetic has SETTLED, and what a slot nobody
                // has shown yet is worth.
                if lengths.wrappedValue <= 0 { lengths.wrappedValue = measured }

                if each, all.wrappedValue[name] != measured {
                    all.wrappedValue[name] = measured
                }
            }
        }

        guard let chooses = slot.chooses, !choice.isNone else { return view }

        // A local rather than `self`: this view holds a class, and a handler
        // closure capturing one can leave this library's executor.
        let choice = choice

        return view.onTapped { choice.choose(chooses) }
    }

    /// The one question - is the reader within `endWithin` items of the end -
    /// as a closure, so every place it can become true asks it in the same
    /// words: the slot at the top changing, the scroller measured, and the run
    /// measured or grown.
    ///
    /// Built out of LOCALS rather than `self`: this view holds a class, and a
    /// handler closure capturing one can leave this library's executor.
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

            // How much is in view is a measurement, and until there is one
            // the reader is nowhere yet.
            guard viewport > 0 else { return }

            let top = plan.clamped(firsts.wrappedValue)
            let last = plan.clamped(top + plan.fits(in: viewport) - 1)

            guard plan.items(after: last) <= within else { return }

            try await endReached()
        }
    }

    /// Which slots are described: the one at the top, the ones that fit after
    /// it, and a margin either side.
    ///
    /// While a KIND has never been measured, it is the first slot of each such
    /// kind instead - wherever in the list that falls, since a footer may be a
    /// thousand items down and the arithmetic cannot settle without it.
    private func window(of plan: Plan) -> [Int] {
        guard plan.slots > 0 else { return [] }

        guard plan.settled else {
            return [Kind.header, .item, .footer]
                .filter { plan.needs($0) }
                .compactMap { plan.first($0) }
                .sorted()
        }

        let measured = axis == .vertical ? measuredHeight : measuredWidth

        // A VIEWPORT AS LONG AS THE WHOLE RUN IS A LIST THAT IS NOT BOUNDED. A
        // stack gives a child the length it asks for, and a scroller asked how
        // long it wants to be answers with its whole content - so a list in one
        // is laid out as long as its run and describes every slot. Said rather
        // than refused, and only where the run is longer than a screen, since a
        // short list standing in a tall box is an ordinary thing.
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

    /// How long the screen is along the axis, in device units - the standing
    /// answer to "how much of this list can be in view" while the scroller's
    /// own measurement has not arrived. Generous by design: it costs a
    /// screenful of slots described, and it is never short.
    private var screenful: Double {
        let side = axis == .vertical ? display.height : display.width

        return display.density > 0 && side > 0 ? side / display.density : 1_000
    }

    /// The length of every slot of the list, in order - what a list measuring
    /// every item is placed by. A slot never in view is worth the estimate;
    /// the slots the reader has passed are measured, which is why nothing
    /// before the reader shifts as the rest of the run is worked out.
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

    /// What a slot is CALLED - the one place the answer is written, so the
    /// slots the window describes and the lengths the plan reads are filed
    /// under the same name.
    private func identity(group: Int, kind: Kind, offset: Int) -> String {
        let shape = source.groups[group]

        if kind != .item {
            return "\(shape.name ?? "\(group)")/\(kind.suffix)"
        }

        let own = String(describing: shape.item(at: offset)[keyPath: shape.path])

        // Under its group, so two groups may hold equal items and keep their
        // own. A group that says nothing is identified by where it SITS, as its
        // header is - and a list of one group prefixes nothing, its items being
        // the only ones there are.
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

    /// What sits at one position of the run.
    private enum Kind: Hashable {
        /// A group's header.
        case header

        /// One of its items.
        case item

        /// Its footer.
        case footer

        /// What an identity says after the group's own name.
        var suffix: String {
            switch self {
            case .header: return "header"
            case .item: return "item"
            case .footer: return "footer"
            }
        }
    }

    /// One group's shape, which is all the arithmetic needs of it.
    private struct GroupShape {
        /// Whether a header stands before its items.
        let header: Bool

        /// How many items it has.
        let items: Int

        /// Whether a footer stands after them.
        let footer: Bool

        /// How many slots the group is, in all.
        var slots: Int { items + (header ? 1 : 0) + (footer ? 1 : 0) }
    }

    /// Which slot a position is, and whose.
    private struct Slot {
        /// Which group it belongs to.
        let group: Int

        /// What it is.
        let kind: Kind

        /// Which item of the group, where it is one.
        let offset: Int
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

    /// Where every group starts, and what each kind of slot is worth.
    ///
    /// The running lists are one longer than the groups: the last entry is the
    /// end, which is the run's own count and length.
    private struct Plan {
        /// The first slot of each group, then the total.
        let starts: [Int]

        /// The start of each group along the axis, then the whole length.
        let tops: [Double]

        /// How many items stand before each group, then the total.
        let itemsBefore: [Int]

        /// The shapes it was built from.
        let shapes: [GroupShape]

        /// What an item measured or was stated at; nought while unmeasured.
        let item: Double

        /// What a group's header measured.
        let header: Double

        /// What a group's footer measured.
        let footer: Double

        /// Where every SLOT starts, then the whole length - built only where
        /// every item is measured, and nil where one answers for all.
        ///
        /// The whole of what a list of unequal items costs: one number per
        /// slot rather than one per group, summed once as the plan is built
        /// and read in one lookup afterwards.
        let each: [Double]?

        /// Builds the sums, one addition per group.
        init(
            shapes: [GroupShape],
            item: Double,
            header: Double,
            footer: Double,
            lengths: [Double]?
        ) {
            var starts = [0]
            var tops = [0.0]
            var itemsBefore = [0]

            // The same lengths `length(of:)` answers, provisional ones
            // included, so a slot placed before its kind is measured stands
            // where the sums say.
            let itemLength = item > 0 ? item : ItemsView.provisional
            let headerLength = header > 0 ? header : ItemsView.provisional
            let footerLength = footer > 0 ? footer : ItemsView.provisional

            for shape in shapes {
                starts.append(starts[starts.count - 1] + shape.slots)
                itemsBefore.append(itemsBefore[itemsBefore.count - 1] + shape.items)
                tops.append(tops[tops.count - 1]
                    + (shape.header ? headerLength : 0)
                    + Double(shape.items) * itemLength
                    + (shape.footer ? footerLength : 0))
            }

            self.starts = starts
            self.tops = tops
            self.itemsBefore = itemsBefore
            self.shapes = shapes
            self.item = item
            self.header = header
            self.footer = footer

            if let lengths {
                var running = [0.0]
                running.reserveCapacity(lengths.count + 1)

                for length in lengths {
                    running.append(running[running.count - 1] + length)
                }

                each = running
            } else {
                each = nil
            }
        }

        /// The step from one item to the next.
        var step: Double { length(of: .item) }

        /// How many slots the whole run is.
        var slots: Int { starts[starts.count - 1] }

        /// How long the whole run is along the axis.
        var extent: Double {
            if let each { return max(0, each[each.count - 1]) }

            return tops[tops.count - 1]
        }

        /// Whether every kind the list has is measured - until then the
        /// arithmetic is provisional and the placed slots measure themselves.
        var settled: Bool {
            !needs(.item) && !needs(.header) && !needs(.footer)
        }

        /// What a kind of slot is worth, provisionally while it has never
        /// been measured.
        func length(of kind: Kind) -> Double {
            let measured: Double

            switch kind {
            case .header: measured = header
            case .item: measured = item
            case .footer: measured = footer
            }

            return measured > 0 ? measured : ItemsView.provisional
        }

        /// Whether a kind the list has is still waiting to be measured. A kind
        /// no group has needs nothing.
        func needs(_ kind: Kind) -> Bool {
            switch kind {
            case .header: return header <= 0 && shapes.contains { $0.header }
            case .item: return item <= 0 && shapes.contains { $0.items > 0 }
            case .footer: return footer <= 0 && shapes.contains { $0.footer }
            }
        }

        /// The first slot of a kind, wherever in the run it falls - what
        /// measures that kind for all of them.
        func first(_ kind: Kind) -> Int? {
            for (index, shape) in shapes.enumerated() {
                switch kind {
                case .header where shape.header:
                    return starts[index]

                case .item where shape.items > 0:
                    return starts[index] + (shape.header ? 1 : 0)

                case .footer where shape.footer:
                    return starts[index] + (shape.header ? 1 : 0) + shape.items

                default:
                    continue
                }
            }

            return nil
        }

        /// How many slots fit in a viewport, counted off the SHORTEST slot the
        /// run has, so the answer is never short: a window a slot too small is
        /// a band of nothing at the end of the view.
        func fits(in viewport: Double) -> Int {
            max(1, Int((viewport / max(shortest, 1)).rounded(.up)))
        }

        /// The shortest slot the run has.
        private var shortest: Double {
            if let each, each.count > 1 {
                var least = Double.greatestFiniteMagnitude

                for index in 1..<each.count {
                    least = min(least, each[index] - each[index - 1])
                }

                return least
            }

            var least = step

            if shapes.contains(where: { $0.header }) { least = min(least, length(of: .header)) }
            if shapes.contains(where: { $0.footer }) { least = min(least, length(of: .footer)) }

            return least
        }

        /// Which slot a position is, and whose.
        func slot(_ index: Int) -> Slot {
            let group = self.group { starts[$0] <= index }
            let shape = shapes[group]
            var offset = index - starts[group]

            if shape.header {
                if offset == 0 { return Slot(group: group, kind: .header, offset: 0) }
                offset -= 1
            }

            if offset < shape.items { return Slot(group: group, kind: .item, offset: offset) }

            return Slot(group: group, kind: .footer, offset: 0)
        }

        /// Where a slot starts along the axis.
        func start(of index: Int) -> Double {
            if let each { return each[min(max(0, index), each.count - 1)] }

            let slot = slot(index)
            let shape = shapes[slot.group]
            var start = tops[slot.group]

            if shape.header && slot.kind != .header { start += length(of: .header) }
            if slot.kind == .item { start += Double(slot.offset) * step }
            if slot.kind == .footer { start += Double(shape.items) * step }

            return start
        }

        /// How many ITEMS stand after a slot - what the end of the list is
        /// counted in, a group's header and footer being no items.
        func items(after index: Int) -> Int {
            let slot = slot(clamped(index))
            let through: Int

            switch slot.kind {
            case .header: through = 0
            case .item: through = slot.offset + 1
            case .footer: through = shapes[slot.group].items
            }

            return itemsBefore[itemsBefore.count - 1] - itemsBefore[slot.group] - through
        }

        /// A slot the run actually has.
        func clamped(_ index: Int) -> Int { min(max(0, index), max(0, slots - 1)) }

        /// Which slot is at a position along the axis - the other direction.
        ///
        /// Worked out in lengths and held to the group's own items before it
        /// becomes a whole number, so an offset far past the end is still a
        /// slot rather than a number too large to count.
        func slot(at along: Double) -> Int {
            if let each {
                // The last slot starting at or before the position, found the
                // way the groups are: a list of unequal items may be as long
                // as it likes.
                var low = 0
                var high = each.count - 2

                while low < high {
                    let middle = (low + high + 1) / 2
                    if each[middle] <= along { low = middle } else { high = middle - 1 }
                }

                return clamped(low)
            }

            let group = self.group { tops[$0] <= along }
            let shape = shapes[group]
            var rest = along - tops[group]

            if shape.header {
                if rest < length(of: .header) { return starts[group] }
                rest -= length(of: .header)
            }

            let last = max(0, shape.items - 1)
            let item = rest > 0 ? Int(min(rest / step, Double(last))) : 0

            return clamped(starts[group] + (shape.header ? 1 : 0) + item)
        }

        /// The last group whose start is at or before a position - a binary
        /// search, because a list may have as many groups as it likes.
        private func group(_ isBefore: (Int) -> Bool) -> Int {
            var low = 0
            var high = shapes.count - 1

            while low < high {
                let middle = (low + high + 1) / 2
                if isBefore(middle) { low = middle } else { high = middle - 1 }
            }

            return max(0, low)
        }
    }

    /// What the list shows, and how an item is described - by reference, so
    /// the state walk stops before the items.
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

/// One group of an `ItemsView`: its items, and what stands before and after
/// them.
///
///     ItemsGroup(shelf.items) { item in
///         Label(item)
///     }
///     .id(shelf.name)
///     .header(Label(shelf.name))
///     .footer(Label("\(shelf.items.count) items"))
///
/// Not a view: a group is data the list lays out, and these are all it says.
/// Its header and footer are slots in the same run as the items, each kind
/// measured once for the whole list - so every group's header is given the
/// same shape, and so is every footer.
public struct ItemsGroup<Items: RandomAccessCollection, Id: Hashable> {
    /// What this group shows, one item each.
    let items: Items

    /// Which part of an element is its identity.
    let path: KeyPath<Items.Element, Id>

    /// The item template.
    let template: (Items.Element) -> Element

    /// Who this group is among its siblings, where the author said.
    var name: String?

    /// What stands before the items.
    var head: (any View)?

    /// And after them.
    var foot: (any View)?

    /// One item per element, the element its identity - the list's own
    /// initializer, one level down.
    ///
    /// - Parameters:
    ///   - items: What this group shows.
    ///   - content: The item template, run for the items in view.
    public init(
        _ items: Items,
        content: @escaping (Items.Element) -> Element
    ) where Items.Element: Hashable, Id == Items.Element {
        self.init(items, id: \.self, content: content)
    }

    /// The same, for elements identified by the part `id` names.
    ///
    /// - Parameters:
    ///   - items: What this group shows.
    ///   - id: Which part of an element is its identity.
    ///   - content: The item template, run for the items in view.
    public init(
        _ items: Items,
        id: KeyPath<Items.Element, Id>,
        content: @escaping (Items.Element) -> Element
    ) {
        self.items = items
        self.path = id
        self.template = content
    }

    /// Who this group is among its siblings - what its items' identities are
    /// written under, so two groups may hold equal items and keep their own.
    /// A group that says nothing is identified by where it sits.
    ///
    /// - Parameter value: The group's identity.
    /// - Returns: The group, under that name.
    public func id(_ value: some Hashable) -> Self {
        var copy = self
        copy.name = String(describing: value)
        return copy
    }

    /// What is drawn before the group's items, scrolling with them.
    ///
    /// - Parameter view: What stands before the items.
    /// - Returns: The group, headed by that view.
    public func header(_ view: any View) -> Self {
        var copy = self
        copy.head = view
        return copy
    }

    /// What is drawn after the group's items, scrolling with them.
    ///
    /// - Parameter view: What stands after the items.
    /// - Returns: The group, followed by that view.
    public func footer(_ view: any View) -> Self {
        var copy = self
        copy.foot = view
        return copy
    }

    /// The element at an offset - the one place a collection that is not an
    /// Array is indexed.
    func item(at offset: Int) -> Items.Element {
        items[items.index(items.startIndex, offsetBy: offset)]
    }
}

#endif
