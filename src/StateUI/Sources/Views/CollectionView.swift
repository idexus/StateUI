// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The library's own list, under MAUI's name for one.
//
//     CollectionView(items) { item in
//         ItemRow(item: item)
//     }
//     .selection($chosen)
//     .heightRequest(240)
//
// WHY IT EXISTS. MAUI's CollectionView is a platform recycler, and what it
// asks of a template is that the row be right AT BIND TIME - which a
// description crossing a boundary cannot promise: a row built a dispatcher
// turn late re-enters the measurement pass on iOS, and a row described eagerly
// costs the whole list on every change. So this list asks the platform for
// nothing it cannot keep: a ScrollView, an AbsoluteLayout, and views placed by
// arithmetic. There is one list in this library, and it is this one.
//
// AND IT KEEPS THE NAME, because that is the name a reader looks under: a
// list of items with a template is a CollectionView wherever they have met
// one. What is behind it is this library's own code rather than MAUI's
// control, which is what the `///` below says out loud - the same as
// `CarouselView` beside it. Everything else in the library IS MAUI's, so
// these two are the exceptions worth naming.
//
// HOW IT IS LAZY. One row is measured - the first one placed - and its height
// is every row's, so the list's whole height is the count times that number.
// A scroller whose content height is known needs no rows to compute it, which
// is what lets the rows themselves be described only where the reader is
// looking: the scroll position says which row is at the top, the measured
// viewport says how many fit, and the window is that span plus a few rows
// either side. Everything outside it is not described, not built, not sent.
//
// GROUPS ARE THE SAME ARITHMETIC, one level up. A grouped list is a run of
// SLOTS - a heading, its rows, its footing, the next heading - and each KIND
// is measured once, so where any slot sits is a sum over the groups above it.
// That sum is computed once per render, over the groups rather than the rows,
// which is why a hundred groups of a thousand rows costs a hundred additions.
//
// WHAT IT COSTS, said out loud. Rows are UNIFORM: the first one measured
// decides, and a row that wants to be taller is squeezed - `.itemSize()`
// states the number instead of measuring it. A row that scrolls out of the
// window leaves the tree, so its control goes and its own `@State` with it;
// what must outlive the window belongs in the page, keyed by the item, which
// is the rule a recycled list has anyway.
//
// WHAT IS NOT HERE. Nothing crosses the boundary that did not already: there
// is no node type, no Reconcile case, no fixture and no styles arm - a
// CollectionView is a composed view like `FrameReader`, made of controls that
// already exist. Which is also why it works on every platform at once. A row
// that acts on a swipe is a `SwipeView` around the row, MAUI's own control,
// written in the template like any other view.

/// A list that describes only the items it can see.
///
/// **This is the library's own, not MAUI's control** - written in Swift over a
/// ScrollView and an AbsoluteLayout, and carrying MAUI's name because that is
/// what a reader looks under. Its properties are its own for the same reason:
/// there is no MAUI member behind them.
///
///     CollectionView(files, id: \.path) { file in
///         FileRow(file: file)
///     }
///     .selection($chosen)
///     .heightRequest(320)
///
/// The initializer IS the row template, run here - one row per item, the item
/// its identity, exactly as `ForEach` reads a collection. What is different is
/// how many of them are described: the rows on screen, and a few either side,
/// whatever the list's length.
///
/// **Items are all one size.** The first one placed is measured and every item
/// is given that size, which is what lets the list know how long it is without
/// describing anything. State the number with `.itemSize()` where the items are
/// bigger than their content, or where measuring one of them would be
/// misleading.
///
/// **It runs DOWN unless `.orientation(.horizontal)` says otherwise**, and
/// across it is the same arithmetic on the other axis: an item takes the whole
/// height of the list, and `.itemSize()` is its width. `.snapToItem(true)` then
/// makes a throw come to rest with an item at the edge.
///
/// **It needs to be bounded ACROSS the way it scrolls**, like any scroller: a
/// `.heightRequest` or a star row of a Grid for a list that runs down, a
/// `.heightRequest` again for one that runs across - a scroller with no size
/// across its axis is measured at nothing. In a bare VStack a downward list is
/// measured at the height of all its rows and has nothing left to scroll.
///
/// **A row scrolled out of the window leaves the tree**, so its control goes
/// and the row's own `@State` with it. What must outlive the window - a
/// half-typed edit, whether a row is expanded - belongs in the page, keyed by
/// the item, which is the rule a recycled list asks for anyway.
///
/// Write this list's own modifiers - `.selection`, `.header`, `.itemSize` -
/// before the ones every view has, since `.heightRequest` and its kind give
/// back the wrapper every composed view's modifiers give back.
public struct CollectionView<Items: RandomAccessCollection, Id: Hashable>: ContentView {
    // The state is declared FIRST, deliberately: the boxes are adopted by
    // position in declaration order (Core/Stateful.swift), and a header stored
    // below may be a composed view carrying boxes of its own. Above them, this
    // list's own are always the first, whatever it is furnished with.

    /// What the first placed row measured - the height every row is given, and
    /// the number the whole geometry is computed from. Zero until it settles.
    @State private var measuredRow = 0.0

    /// The same for a group's heading, measured once and answering for all of
    /// them.
    @State private var measuredHeading = 0.0

    /// And for a group's footing.
    @State private var measuredFooting = 0.0

    /// How wide the visible part of the list is, as layout settled it.
    ///
    /// The two sides are kept as WIDTH and HEIGHT rather than as along-the-axis
    /// and across it, because the axis can change without the frame doing: a
    /// list turned to run across is the same rectangle, and it would wait for a
    /// report that never comes.
    @State private var measuredWidth = 0.0

    /// And how tall.
    @State private var measuredHeight = 0.0

    /// Where the rows begin, past whatever header there is - what the scroll
    /// offset is measured against, along the way the list runs.
    @State private var rowsStart = 0.0

    /// The slot at the top of the viewport, which is what the window is drawn
    /// around - and, where the list shows ONE ITEM AT A TIME, the item the
    /// scroller says it is nearest.
    @State private var firstShown = 0

    /// Which slot the DESCRIBED window is drawn around, where that is not the
    /// slot the list is on - see `centred(_:)`. It follows `firstShown` when
    /// the movement STOPS, and in flight only where a swipe has outrun it.
    @State private var loaded = 0

    /// How long the run MEASURED, which is not the same as how long it was
    /// asked to be: a scroller cannot be moved past content it has not been
    /// laid out with yet, so this is what says an offset can be reached.
    @State private var reach = 0.0

    /// The step the last re-centring was made against - what says whether the
    /// GEOMETRY has moved since, which is the only thing an item has to be put
    /// back for.
    @State private var centredAt = 0.0

    /// The scroller, for the list's own moves. The author's own takes its
    /// place where one was assigned, there being one slot on the control.
    @State private var ownScroller = ControlState<ScrollView>()

    /// The screen, which is what a list falls back to while nothing has told
    /// it how tall IT is: no list is taller than the window it is in, so a
    /// screenful of rows is an answer that is never short. Measured on a
    /// CPH2363, where the scroller's own frame report arrives late and a list
    /// that trusted it showed a band of nothing under its last row.
    @Environment private var display: DeviceDisplay

    /// The groups and their row templates, held BY REFERENCE - which is what
    /// stops the state walk here. `Node.composed` reflects a view's stored
    /// properties every time the placeholder is built, and reflecting a
    /// hundred thousand items per render is exactly what a lazy list exists
    /// not to do; the walk stops at any class. See Core/Stateful.swift.
    private let source: Source

    /// The size the author stated, rather than one measured from an item.
    private var stated: Double?

    /// Which way the items run.
    private var axis = CollectionOrientation.vertical

    /// Whether a scroll comes to rest with an item at the edge.
    private var snaps = false

    /// What is drawn above everything, scrolling with the rows.
    private var head: Element?

    /// And below everything.
    private var foot: Element?

    /// What stands in when there are no rows at all.
    private var empty: Element?

    /// Where the choice lives, and how much of one it is.
    private var selection = Selection.none

    /// How close to the end is close enough to ask for more.
    private var threshold = -1

    /// What to run when it gets that close.
    private var more: EventHandler?

    /// The scroller this list is, for an act that wants to move it.
    private var scroller: ControlState<ScrollView>?

    /// The item's length as a fraction of the visible area, where it is taken
    /// from the view rather than measured or stated - see `itemFraction(_:)`.
    private var fraction: Double?

    /// The gap between one item and the next.
    private var spacing = 0.0

    /// Whether the list shows ONE ITEM AT A TIME, centred - see
    /// `centred(_:)`.
    private var centres = false

    /// How much of the platform's own throw a fling keeps, where anything
    /// says.
    private var carry: Double?

    /// The most items one swipe may cross. Zero is as many as it carries.
    private var limit = 0

    /// Where the item the list is on is written, when a binding was lent.
    private var pin: Binding<Int>?

    /// What runs when that item changes, beside any binding.
    private var moved: ValueEventHandler<Int>?

    /// Whether a move the list makes itself glides or jumps.
    private var glidesToPosition = true

    /// How many rows above and below the visible ones are described anyway, so
    /// an ordinary flick finds them already there. Rows are cheap here and a
    /// blank row is not, which is what decides the number - and an item that
    /// takes the whole view is not cheap, which is what decides the other.
    private var span: Int { centres ? 2 : 6 }

    /// What a slot is given while its own kind has never been measured - one
    /// render's worth of arithmetic, replaced by the measurement it makes.
    private static var provisional: Double { 44 }

    /// One row per item, the item its identity.
    ///
    ///     CollectionView(rows) { row in
    ///         Label("Row \(row)")
    ///     }
    ///
    /// - Parameters:
    ///   - items: What the list shows, one row each.
    ///   - content: The row template, run for the rows that can be seen.
    public init(
        _ items: Items,
        content: @escaping (Items.Element) -> Element
    ) where Items.Element: Hashable, Id == Items.Element {
        self.init(items, id: \.self, content: content)
    }

    /// The same, for items identified by the part `id` names - `ForEach`'s own
    /// second form, for items that are not `Hashable` whole or that repeat.
    ///
    ///     CollectionView(files, id: \.path) { file in
    ///         FileRow(file: file)
    ///     }
    ///
    /// - Parameters:
    ///   - items: What the list shows, one row each.
    ///   - id: Which part of an item is its identity - and what a selection
    ///     is made of.
    ///   - content: The row template, run for the rows that can be seen.
    public init(
        _ items: Items,
        id: KeyPath<Items.Element, Id>,
        content: @escaping (Items.Element) -> Element
    ) {
        source = Source(groups: [CollectionGroup(items, id: id, content: content)])
    }

    /// Rows under headings: the groups, each holding its rows and whatever
    /// stands above and below them.
    ///
    ///     CollectionView(groups: shelves.map { shelf in
    ///         CollectionGroup(shelf.items) { Label($0) }
    ///             .id(shelf.name)
    ///             .header(Label(shelf.name))
    ///             .footer(Label("\(shelf.items.count) items"))
    ///     })
    ///
    /// A heading and a footing are SLOTS in the same run as the rows - each
    /// kind measured once, so where a slot sits is a sum over the groups above
    /// it. An ARRAY rather than a builder closure, deliberately: the groups
    /// are data, and a trailing closure would read as the row template.
    ///
    /// A selection's identities must be distinct across the whole list, since
    /// a chosen row is named by its item and not by where it sits.
    public init(groups: [CollectionGroup<Items, Id>]) {
        source = Source(groups: groups)
    }

    /// How long to make every item, instead of measuring the first one - its
    /// HEIGHT in a list that runs down, its WIDTH in one that runs across.
    ///
    /// A list that says nothing measures one item and uses that, which is right
    /// while the items describe their own size. State the number where they do
    /// not - an item of a fixed design, or one whose first is shorter than the
    /// rest. A group's heading and footing are measured either way.
    public func itemSize(_ value: Double) -> Self {
        var copy = self
        copy.stated = value
        return copy
    }

    /// Which way the items run, and which way the reader scrolls. Down unless
    /// this says otherwise.
    ///
    ///     CollectionView(cards) { card in … }
    ///         .orientation(.horizontal)
    ///         .itemSize(180)
    ///
    /// The whole geometry is the same arithmetic along the other axis: an item
    /// takes the full height of the list going across, as it takes the full
    /// width going down.
    public func orientation(_ value: CollectionOrientation) -> Self {
        var copy = self
        copy.axis = value
        return copy
    }

    /// Makes a scroll come to rest with an item at the list's edge, rather
    /// than wherever the throw ran out.
    ///
    ///     CollectionView(pages) { page in … }
    ///         .orientation(.horizontal)
    ///         .snapToItem(true)
    ///
    /// The platform's own braking does it - see `ScrollView.snapInterval(_:from:)`,
    /// which this is - so a throw still lands as far along as its speed
    /// deserves and the movement is the platform's own.
    ///
    /// **A GROUPED list is left alone**, and this quietly does nothing there: a
    /// heading is not the height of a row, so the rows below it stand off any
    /// grid a fixed step could describe. It is for a plain run of items.
    public func snapToItem(_ value: Bool) -> Self {
        var copy = self
        copy.snaps = value
        return copy
    }

    /// What is drawn above the first row, scrolling with the list.
    /// MAUI: StructuredItemsView.Header, which this is the plain-Swift answer
    /// to - an ordinary view above the rows.
    public func header(_ view: Element) -> Self {
        var copy = self
        copy.head = view
        return copy
    }

    /// And below the last. MAUI: StructuredItemsView.Footer.
    public func footer(_ view: Element) -> Self {
        var copy = self
        copy.foot = view
        return copy
    }

    /// What the list shows while it has no rows at all.
    /// MAUI: ItemsView.EmptyView - and here it draws between the header and
    /// the footer on every platform, rather than on some of them.
    public func emptyView(_ view: Element) -> Self {
        var copy = self
        copy.empty = view
        return copy
    }

    /// Which row is chosen: tapping one writes its identity back, and tapping
    /// it again clears the choice.
    ///
    ///     @State private var chosen: String?
    ///
    ///     CollectionView(names) { name in
    ///         Label(name)
    ///             .backgroundColor(chosen == name ? .cornflowerBlue : .transparent)
    ///     }
    ///     .selection($chosen)
    ///
    /// The binding's TYPE is what says how many rows may be chosen - one here,
    /// a `Set` in the overload below - so there is no mode to set beside it and
    /// no state it can disagree with. A list nobody lends a binding to is not
    /// selectable at all.
    ///
    /// What a chosen row LOOKS like is the template's business: it reads the
    /// same state the binding writes, which is why the row above can say so in
    /// one line and why a selection can be drawn any way at all.
    public func selection(_ binding: Binding<Id?>) -> Self {
        var copy = self
        copy.selection = .one(binding)
        return copy
    }

    /// The same, for as many rows as the reader taps: each tap adds or removes
    /// that row's identity.
    ///
    ///     @State private var chosen: Set<String> = []
    ///
    ///     CollectionView(names) { name in
    ///         Label(name)
    ///             .backgroundColor(chosen.contains(name) ? .cornflowerBlue : .transparent)
    ///     }
    ///     .selection($chosen)
    public func selection(_ binding: Binding<Set<Id>>) -> Self {
        var copy = self
        copy.selection = .many(binding)
        return copy
    }

    /// How close to the end the reader may get - counted in rows not yet
    /// scrolled to - before `onRemainingItemsThresholdReached` runs.
    /// MAUI: ItemsView.RemainingItemsThreshold, and the same convention: -1,
    /// the default, means never; 0 asks as the last row shows.
    public func remainingItemsThreshold(_ value: Int) -> Self {
        var copy = self
        copy.threshold = value
        return copy
    }

    /// Runs when the list has been scrolled to within
    /// `remainingItemsThreshold` rows of its end: append the next batch to the
    /// items and the new rows are there when the reader arrives.
    ///
    ///     CollectionView(items) { Label($0) }
    ///         .remainingItemsThreshold(20)
    ///         .onRemainingItemsThresholdReached { items += nextBatch() }
    ///
    /// Asked once per row the window moves by, not once per scroll tick - but
    /// still more than once while the reader stays down there, so the handler
    /// guards on what it has already loaded, the way MAUI's own engine asks
    /// for.
    public func onRemainingItemsThresholdReached(_ handler: @escaping EventHandler) -> Self {
        var copy = self
        copy.more = handler
        return copy
    }

    /// The scroller this list is, so an act can move it.
    ///
    ///     @State private var list = ControlState<ScrollView>()
    ///
    ///     CollectionView(items) { … }.itemSize(44).assign(list)
    ///     Button("Top").onClicked { try await list.scrollTo(x: 0, y: 0) }
    ///
    /// A `ControlState<ScrollView>`, because that is what this list IS from the
    /// outside - so it takes a ScrollView's acts, offsets and all. A row's
    /// offset is its number times the row height, which is the other reason a
    /// list that means to be scrolled about states `.itemSize()`; an offset
    /// past the end is clamped by the platform, so a very large one is "the
    /// end" wherever that turns out to be.
    public func assign(_ state: ControlState<ScrollView>) -> Self {
        var copy = self
        copy.scroller = state
        return copy
    }

    // MARK: - The other form of a list

    /// The item's length along the axis as a FRACTION of the visible area,
    /// instead of a measurement or a stated size.
    ///
    /// The size is then known as soon as the scroller has been measured, and
    /// it is the same on a phone and on a desktop. Internal because it is the
    /// geometry `CarouselView` is built out of; a list states `itemSize(_:)`
    /// or lets the first item measure itself.
    internal func itemFraction(_ value: Double) -> Self {
        var copy = self
        copy.fraction = min(1, max(0.05, value))
        return copy
    }

    /// The gap between one item and the next, in device units.
    ///
    /// Uniform lists only - a heading is not the size of a row, so a run of
    /// mixed slots has no one step to space.
    internal func itemSpacing(_ value: Double) -> Self {
        var copy = self
        copy.spacing = max(0, value)
        return copy
    }

    /// ONE ITEM AT A TIME, in the MIDDLE of the visible area.
    ///
    /// Four things follow from it, and they are all the same decision:
    ///
    /// - the run is PADDED at each end by what is left over either side of an
    ///   item, so the first item is centred at an offset of nothing and the
    ///   last at the very end, and neither can be scrolled past into emptiness;
    /// - one item fits, whatever the arithmetic would otherwise make of the
    ///   viewport, so the window is drawn around the item the list is ON;
    /// - the list hears `snapItem` rather than the offset - which item the
    ///   scroller is NEAREST, by the same rounding that chose where to land,
    ///   so it is named while the movement is still under way;
    /// - and the window waits for the movement to STOP unless a swipe outruns
    ///   it, because an item the size of the view is a control the platform has
    ///   to build and building one under a finger is seen.
    internal func centred(_ value: Bool) -> Self {
        var copy = self
        copy.centres = value
        return copy
    }

    /// How much of the platform's own throw a fling keeps - see
    /// `ScrollView.momentum(_:)`.
    internal func momentum(_ fraction: Double) -> Self {
        var copy = self
        copy.carry = max(0, fraction)
        return copy
    }

    /// The most items one swipe may cross. Zero is as many as the throw
    /// carries, and is the default. `ScrollView.snapsAtMost(_:)`.
    internal func snapsAtMost(_ items: Int) -> Self {
        var copy = self
        copy.limit = max(0, items)
        return copy
    }

    /// Which item the list is ON - the one at the leading edge, or the centred
    /// one where it shows one at a time - written back as the reader moves and
    /// glided to when it is assigned.
    ///
    /// Internal, and deliberately: MAUI's `CollectionView` has no such
    /// property, and this is the state `CarouselView.position` is made of.
    internal func position(_ binding: Binding<Int>, glides: Bool) -> Self {
        var copy = self
        copy.pin = binding
        copy.glidesToPosition = glides
        return copy
    }

    /// Another item came to the edge or the middle, and this is which one.
    internal func onPositionChanged(_ handler: @escaping ValueEventHandler<Int>) -> Self {
        var copy = self
        copy.moved = handler
        return copy
    }

    /// The scroller, the slots placed inside it, and the measurements that
    /// decide which slots those are.
    public var content: Element {
        let plan = plan
        let window = window(of: plan)
        let vertical = axis == .vertical

        var list = ScrollView {
            if vertical {
                if let head { head }

                body(window, of: plan)

                if let foot { foot }
            } else if head != nil || foot != nil {
                // A list that runs ACROSS and is furnished puts its three
                // parts in a stack of its own, because a scroller given
                // several children stacks them DOWNWARDS - which would hang a
                // horizontal list's rows under its header instead of after it.
                // Unfurnished it needs none, and the rows go straight in.
                HStack {
                    if let head { head }

                    body(window, of: plan)

                    if let foot { foot }
                }
                .spacing(0)
            } else {
                body(window, of: plan)
            }
        }
        // A list with nothing in it has nothing to scroll, and saying so is
        // what BOUNDS whatever stands in for the rows: left scrollable, an
        // empty view is measured against a run that is not there and a line of
        // text walks off both edges.
        .orientation(plan.slots == 0 ? .neither : (vertical ? .vertical : .horizontal))

        if let scroller {
            list = list.assign(scroller)
        } else if pin != nil {
            list = list.assign(ownScroller)
        }

        // A grid of one item, so a throw ends with an item at the edge. Only
        // where every slot IS an item: a heading is a different size, and the
        // rows after one stand off any fixed step. A centred run counts its
        // grid from NOTHING, the pads having put the first item in the middle
        // there.
        if snaps || centres, plan.settled, plan.uniform {
            list = list.snapInterval(plan.step, from: centres ? 0 : rowsStart)
        }

        if let carry, plan.settled {
            list = list.momentum(carry)
        }

        if limit > 0, plan.settled, plan.uniform {
            list = list.snapsAtMost(limit)
        }

        // A run shown one item at a time has no use for a scroll bar: it is
        // one card wide, and the dots under it are what says where the reader
        // is.
        if centres {
            list = list.horizontalScrollBarVisibility(.never).verticalScrollBarVisibility(.never)
        }

        return watching(measuring(scrolling(list, of: plan)), of: plan)
    }

    /// The rows, or whatever stands in for them where there are none.
    @ViewBuilder
    private func body(_ window: [Int], of plan: Plan) -> [Element] {
        if plan.slots == 0 {
            if let empty {
                empty
            }
        } else {
            placed(window, of: plan)
        }
    }

    /// The slots of the window, each where the arithmetic puts it.
    ///
    /// An AbsoluteLayout is the whole trick: its own height is stated - the
    /// sum over the groups - so the scroller knows how far it goes without a
    /// single row having been described, and every slot is placed by its
    /// number rather than by what stands above it.
    private func placed(_ window: [Int], of plan: Plan) -> Element {
        let starts = _rowsStart
        let reaches = _reach
        let ask = asking(plan)
        let vertical = axis == .vertical
        let across = vertical ? measuredWidth : measuredHeight

        return AbsoluteLayout {
            ForEach(rows(window, of: plan), id: \.identity) { row in
                described(row, vertical: vertical)
            }
        }
        // The rows are what a pool is for: a scroll of one row builds one row
        // and drops one, and the two are the same shape whenever the template
        // wrote the same modifiers for both items.
        .recycling()
        // -1 is MAUI's own "no request": while nothing has been measured the
        // slots placed measure themselves, and the sizes arrive with them.
        //
        // The run's own length is stated ALONG the axis. Across it, a list
        // running down fills the scroller by itself and a list running across
        // does NOT - a scroller measuring its content sideways offers it no
        // height, so the layout comes back as tall as one label and every item
        // placed proportionally shrinks to that. So it is told: the scroller's
        // own measured height, which is the same number the viewport is.
        .heightRequest(vertical
            ? (plan.settled ? plan.height : -1)
            : (across > 0 ? across : -1))
        .widthRequest(vertical
            ? (centres && across > 0 ? across : -1)
            : (plan.settled ? plan.height : -1))
        .onFrameChanged { frame in
            let start = vertical ? frame.y : frame.x

            if start != starts.wrappedValue { starts.wrappedValue = start }

            // How long the run was LAID OUT, which is not how long it was
            // asked to be: a scroller cannot be moved past content it has not
            // been laid out with yet, so this is what says an offset can be
            // reached. Measured on an Android phone, where the layout lands a
            // beat after the frame report the size came from and a carousel
            // opened on nothing at all.
            let measured = vertical ? frame.height : frame.width

            if measured != reaches.wrappedValue { reaches.wrappedValue = measured }

            // This frame is the CONTENT's, so it changes when the list grows -
            // which is the other moment "am I near the end" can become true.
            try await ask?()
        }
    }

    /// Every slot of the window, with where it sits and who it is.
    ///
    /// Each position costs a binary search over the GROUPS, which is nothing:
    /// a flat list has one group and a hundred groups are seven comparisons.
    private func rows(_ window: [Int], of plan: Plan) -> [Placed] {
        // While a kind has never been measured, every slot placed is one that
        // measures itself - the window IS that list - and it carries the only
        // frame subscription there will ever be.
        let measuring = plan.settled || fraction != nil ? [] : Set(window)

        return window.compactMap { index in
            let slot = plan.slot(index)
            let group = source.groups[slot.group]

            switch slot.kind {
            case .heading, .footing:
                guard let view = slot.kind == .heading ? group.head : group.foot else { return nil }

                return Placed(
                    identity: "\(group.name ?? "\(slot.group)")/\(slot.kind.suffix)",
                    view: view,
                    chooses: nil,
                    y: plan.top(of: index),
                    height: plan.height(of: slot.kind),
                    measures: measuring.contains(index) ? slot.kind : nil)

            case .row:
                let item = group.item(at: slot.offset)
                let identity = String(describing: item[keyPath: group.path])

                return Placed(
                    identity: group.name.map { "\($0)/\(identity)" } ?? identity,
                    view: group.row(item),
                    chooses: item[keyPath: group.path],
                    y: plan.top(of: index),
                    height: plan.height(of: .row),
                    measures: measuring.contains(index) ? .row : nil)
            }
        }
    }

    /// One slot: the author's view, placed, measured while its kind has never
    /// been, and given a tap where the list is selectable.
    private func described(_ row: Placed, vertical: Bool) -> Element {
        let length = row.measures == nil ? row.height : AbsoluteLayout.autoSize

        var view = ModifiedContent(node: row.view.body)
            .absoluteLayoutBounds(
                vertical ? Rect(0, row.y, 1, length) : Rect(row.y, 0, length, 1))
            // The side ACROSS the axis is the whole of the list; the side along
            // it is the item's own, in device units.
            .absoluteLayoutFlags(vertical ? .widthProportional : .heightProportional)

        if let kind = row.measures {
            let sizes = box(of: kind)

            view = view.onFrameChanged { frame in
                let measured = vertical ? frame.height : frame.width

                if measured > 0 && sizes.wrappedValue <= 0 {
                    sizes.wrappedValue = measured
                }
            }
        }

        guard let chooses = row.chooses, !selection.isNone else {
            return view
        }

        // Locals rather than `self`: a handler closure that captures a plain
        // class can leave this library's executor, and a Binding is the
        // shape that is known to stay put.
        let choice = selection

        return view.onTapped { choice.choose(chooses) }
    }

    /// The scroller, hearing where it has been scrolled to.
    ///
    /// The report is where the WINDOW comes from, and the state is written
    /// only when the slot at the top actually changes - so a flick that
    /// crosses four rows renders four times rather than once per scroll tick.
    private func scrolling(_ list: ScrollView, of plan: Plan) -> ScrollView {
        centres ? snapped(list, of: plan) : offset(list, of: plan)
    }

    /// The scroller, heard as WHICH ITEM it is nearest - the report a list that
    /// shows one at a time lives on.
    ///
    /// It is the platform's own rounding, the same one that chose where the
    /// movement would land, so the item is named while the movement is still
    /// under way and cannot disagree with where it ends. The WINDOW is written
    /// before the position, because the window is what has to be right before
    /// the next frame is drawn and the position is only what tells anyone
    /// watching.
    ///
    /// Built out of LOCALS rather than `self`: this list holds a class, and a
    /// handler closure that captures one can leave this library's executor.
    private func snapped(_ list: ScrollView, of plan: Plan) -> ScrollView {
        let firsts = _firstShown
        let loads = _loaded
        let settle = settling(plan)
        let span = span

        return list
            .addHandler(.snapItemChanged) {
                guard let value = EventBuffer.current.value()?.number, plan.settled else { return }

                let index = plan.clamped(Int(value))
                guard index != firsts.wrappedValue else { return }

                // The one case where the window has to be widened while the
                // movement is still under way: the item reached sits at the
                // EDGE of what is described, so there is nothing in front of it
                // for the movement to carry on into. An ordinary swipe of one
                // item never gets here.
                if abs(index - plan.clamped(loads.wrappedValue)) >= span {
                    loads.wrappedValue = index
                }

                firsts.wrappedValue = index
                try await settle(index)
            }
            // Nothing is moving now, so the items the next swipe will need can
            // be built without any of it being seen.
            .onScrollStopped {
                guard plan.settled else { return }

                let index = plan.clamped(firsts.wrappedValue)
                if loads.wrappedValue != index { loads.wrappedValue = index }
            }
    }

    /// The scroller, hearing where it has been scrolled to.
    private func offset(_ list: ScrollView, of plan: Plan) -> ScrollView {
        let starts = _rowsStart
        let firsts = _firstShown
        let ask = asking(plan)
        let vertical = axis == .vertical

        // Once per ITEM crossed rather than once per frame: the host reports
        // the offset each time it passes a multiple of the item's size, which
        // is as often as the slot at the edge can change. The guard below
        // stays for the reports that cross a multiple without changing the
        // slot - a heading's size is not an item's.
        var stepped = list
        if plan.settled { stepped.node.props[.scrollStep] = .number(plan.height(of: .row)) }

        return stepped.addHandler(vertical ? .scrollYChanged : .scrollXChanged) {
            guard let offset = EventBuffer.current.value()?.number else { return }
            guard plan.settled, plan.slots > 0 else { return }

            let top = plan.slot(at: offset - starts.wrappedValue)
            guard top != firsts.wrappedValue else { return }
            firsts.wrappedValue = top

            try await ask?()
        }
    }

    /// What a settle does once it knows which item it landed on: writes the
    /// position wherever it lives, tells whoever asked, and asks for more
    /// items where the end is close.
    private func settling(_ plan: Plan) -> Settle {
        let pin = pin
        let moved = moved
        let ask = asking(plan)

        return { index in
            if let pin, pin.wrappedValue != index {
                pin.wrappedValue = index

                if let moved {
                    try await moved(index)
                }
            }

            try await ask?()
        }
    }

    /// Where the list is asked to be: the item somebody assigned, and the
    /// length the run settled on - both of which move the offset without the
    /// reader touching anything.
    ///
    /// Only where a position was lent. A list nobody asked about its position
    /// is moved by the reader and by acts, and neither goes through here.
    private func watching(_ list: ScrollView, of plan: Plan) -> Element {
        guard let pin else { return list }

        let firsts = _firstShown
        let steps = _centredAt
        let mover = scroller ?? ownScroller
        let glides = glidesToPosition
        let wanted = pin.wrappedValue
        let vertical = axis == .vertical

        let move: nonisolated(nonsending) (Int, Bool) async throws -> Void = { index, animated in
            let target = plan.offset(of: plan.clamped(index))

            try await mover.scrollTo(
                x: vertical ? 0 : target,
                y: vertical ? target : 0,
                animated: animated)
        }

        let recentre: EventHandler = {
            // The run is laid out at a new LENGTH every time the items grow,
            // and a longer run moves no item: an offset counts from the start
            // and knows nothing about the count. So the item the list is on is
            // put back only when the GEOMETRY moved - a first measurement, a
            // resize, a turn - and items that grew under a reader's finger are
            // left alone. Measured on Mac Catalyst: re-centring on the length
            // pulled a scroll in progress back onto the item it started from.
            guard plan.settled, steps.wrappedValue != plan.step else { return }

            steps.wrappedValue = plan.step
            try await move(firsts.wrappedValue, false)
        }

        return list
            .onChanged(wanted) {
                // A position the scroller REPORTED is where the list already
                // is, and moving to it would report again - so only a position
                // somebody ASSIGNED moves anything. That is the whole of what
                // this has to know about who moved it.
                guard plan.settled, plan.clamped(wanted) != firsts.wrappedValue else { return }

                firsts.wrappedValue = plan.clamped(wanted)
                try await move(wanted, glides)
            }
            // The run was laid out at a new length - the first time, after a
            // resize, after a turn, or because the items grew - so the offset
            // that put an item where it reads no longer does, and this is the
            // first moment the new one can be reached.
            .onChanged(reach, recentre)
    }

    /// What a settle runs once it knows which item it landed on.
    private typealias Settle = nonisolated(nonsending) (Int) async throws -> Void

    /// The one question - is the reader within `remainingItemsThreshold` slots
    /// of the end - as a closure, so the two places it can become true ask it
    /// in exactly the same words.
    ///
    /// A SCROLL is the obvious one. The other is the list being MEASURED or
    /// GROWING while everything already fits: a batch shorter than the view
    /// leaves the reader at the end with nothing left to scroll, so no scroll
    /// is ever reported and the loading stalls after the first batch. Measured
    /// on Windows, where a maximized window held the whole first
    /// batch of thirty and the list never asked again. The content's own frame
    /// report is what closes it: every appended batch makes that frame taller,
    /// so the question is put again until the list outgrows the view - or the
    /// author's own guard stops it, which is the guard this needs anyway.
    ///
    /// Built out of LOCALS rather than `self`: this list holds a class, and a
    /// handler closure that captures one can leave this library's executor -
    /// which is also why the answer is an `EventHandler`, the library's own
    /// alias, rather than a bare closure type: it carries the marker that says
    /// where it runs.
    private func asking(_ plan: Plan) -> EventHandler? {
        guard threshold >= 0, let more else { return nil }

        let threshold = threshold
        let firsts = _firstShown
        let widths = _measuredWidth
        let heights = _measuredHeight
        let vertical = axis == .vertical

        return {
            guard plan.settled, plan.slots > 0 else { return }

            let fits = plan.fits(in: vertical ? heights.wrappedValue : widths.wrappedValue)
            guard plan.slots - (firsts.wrappedValue + fits) <= threshold else { return }

            try await more()
        }
    }

    /// The scroller, hearing how big it is - which is how many items fit.
    private func measuring(_ list: ScrollView) -> ScrollView {
        let widths = _measuredWidth
        let heights = _measuredHeight

        return list.onFrameChanged { frame in
            if frame.width != widths.wrappedValue { widths.wrappedValue = frame.width }
            if frame.height != heights.wrappedValue { heights.wrappedValue = frame.height }
        }
    }

    /// Which slots are described: the one at the top, the ones that fit under
    /// it, and a margin either side.
    ///
    /// While a KIND has never been measured, it is the first slot of each such
    /// kind instead - wherever in the list that falls, since a footing may be
    /// a thousand rows down and the geometry cannot settle without it.
    private func window(of plan: Plan) -> [Int] {
        guard plan.slots > 0 else { return [] }

        guard plan.settled || fraction != nil else {
            return [Kind.heading, .row, .footing]
                .filter { plan.needs($0) }
                .compactMap { plan.first($0) }
                .sorted()
        }

        let measured = axis == .vertical ? measuredHeight : measuredWidth
        let fits = plan.fits(in: measured > 0 ? measured : screenful)
        let span = span
        let around = { (index: Int) -> Range<Int> in
            let first = max(0, index - span)
            let last = min(plan.slots, index + fits + span)

            return first..<max(first + 1, last)
        }
        // Where one item is shown at a time the window waits for the movement
        // to stop - see centred(_:) - so it is drawn around what has been
        // LOADED and not around what the scroller has reached.
        let top = min(centres ? loaded : firstShown, plan.slots - 1)

        // TWO windows rather than one span: an item somebody ASSIGNED is
        // somewhere else entirely, and its neighbours have to be described
        // before the move to them can begin - while a span between the fifth
        // item and the five hundredth would describe every item there is.
        guard let pin, plan.clamped(pin.wrappedValue) != plan.clamped(firstShown) else {
            return Array(around(top))
        }

        // Sorted, because a Set has no order and a message must be the same
        // bytes every run - Core/Wire.swift's rule.
        return Set(around(top))
            .union(around(plan.clamped(pin.wrappedValue)))
            .sorted()
    }

    /// Where every group starts, in slots and in points - computed once per
    /// render, over the GROUPS rather than the rows.
    private var plan: Plan {
        let viewport = axis == .vertical ? measuredHeight : measuredWidth
        let row = fraction.map { viewport * $0 } ?? stated ?? measuredRow

        return Plan(
            shapes: source.groups.map {
                Shape(heading: $0.head != nil, rows: $0.items.count, footing: $0.foot != nil)
            },
            row: row,
            heading: measuredHeading,
            footing: measuredFooting,
            spacing: spacing,
            // What is left over either side of an item, which is what makes
            // the arithmetic fall out: item `i` is centred by an offset of `i`
            // steps, the first at nothing and the last at the very end.
            pad: centres ? max(0, (viewport - row) / 2) : 0,
            centres: centres)
    }

    /// How tall the screen is, in the units a layout speaks - the standing
    /// answer to "how much of this list can possibly be visible" while the
    /// scroller's own measurement has not arrived. The number is generous by
    /// design: it costs a screenful of rows described and it is never short.
    private var screenful: Double {
        let side = axis == .vertical ? display.height : display.width

        return display.density > 0 ? side / display.density : 1_000
    }

    /// Where a measured height is kept, by the kind that measured it.
    private func box(of kind: Kind) -> State<Double> {
        switch kind {
        case .row: return _measuredRow
        case .heading: return _measuredHeading
        case .footing: return _measuredFooting
        }
    }

    /// What sits at one position in the list.
    private enum Kind: Hashable {
        /// A group's heading.
        case heading

        /// One of its rows.
        case row

        /// Its footing.
        case footing

        /// What an identity says after the group's own name.
        var suffix: String {
            switch self {
            case .heading: return "heading"
            case .row: return "row"
            case .footing: return "footing"
            }
        }
    }

    /// One group's shape, which is all the arithmetic needs of it.
    private struct Shape {
        /// Whether a heading stands above its rows.
        let heading: Bool

        /// How many rows it has.
        let rows: Int

        /// Whether a footing stands below them.
        let footing: Bool

        /// How many slots the group is, in all.
        var slots: Int { rows + (heading ? 1 : 0) + (footing ? 1 : 0) }
    }

    /// Which slot a position is, and whose.
    private struct Slot {
        /// Which group it belongs to.
        let group: Int

        /// What it is.
        let kind: Kind

        /// Which row of the group, when it is one.
        let offset: Int
    }

    /// One slot of the window, ready to be described.
    private struct Placed {
        /// Who it is, in the id namespace the author writes in.
        let identity: String

        /// What it shows.
        let view: Element

        /// What a tap on it would choose - a row's item, and nothing for a
        /// heading or a footing.
        let chooses: Id?

        /// Where it sits, in points down the list.
        let y: Double

        /// How tall it is.
        let height: Double

        /// Which kind's height it is measuring, when it is the first of one
        /// nobody has measured.
        let measures: Kind?
    }

    /// Where every group starts, and what each kind of slot is worth.
    ///
    /// The lists are one longer than the groups: the last entry is the end,
    /// which is the list's own count and height.
    private struct Plan {
        /// The first slot of each group, then the total.
        let starts: [Int]

        /// The top of each group, then the whole height.
        let tops: [Double]

        /// The shapes it was built from.
        let shapes: [Shape]

        /// What a row is worth.
        let row: Double

        /// A heading, where there are any.
        let heading: Double

        /// And a footing.
        let footing: Double

        /// The gap between one row and the next.
        let spacing: Double

        /// What stands at each end of the run, so an item can be brought to the
        /// middle - nothing, unless the list shows one item at a time.
        let pad: Double

        /// Whether one item is shown at a time.
        let centres: Bool

        /// Builds the sums, one addition per group.
        init(
            shapes: [Shape],
            row: Double,
            heading: Double,
            footing: Double,
            spacing: Double,
            pad: Double,
            centres: Bool
        ) {
            var starts = [0]
            var tops = [0.0]
            let run = { (rows: Int) in
                rows > 0 ? Double(rows) * row + Double(rows - 1) * spacing : 0
            }

            for shape in shapes {
                starts.append(starts[starts.count - 1] + shape.slots)
                tops.append(tops[tops.count - 1]
                    + (shape.heading ? heading : 0)
                    + run(shape.rows)
                    + (shape.footing ? footing : 0))
            }

            self.starts = starts
            self.tops = tops
            self.shapes = shapes
            self.row = row
            self.heading = heading
            self.footing = footing
            self.spacing = spacing
            self.pad = pad
            self.centres = centres
        }

        /// One row and the gap after it - the step from one to the next.
        var step: Double { height(of: .row) + spacing }

        /// How many slots the whole list is.
        var slots: Int { starts[starts.count - 1] }

        /// Whether every slot is an ITEM - no heading and no footing anywhere,
        /// so the run is one size all the way down and a fixed grid describes
        /// it.
        var uniform: Bool { shapes.allSatisfy { !$0.heading && !$0.footing } }

        /// And how tall it is, the pads at each end included.
        var height: Double { tops[tops.count - 1] + 2 * pad }

        /// Whether every kind the list actually has is measured - until then
        /// the arithmetic is provisional and the placed slots are measuring
        /// themselves.
        var settled: Bool {
            if row <= 0 { return false }
            if heading <= 0 && shapes.contains(where: { $0.heading }) { return false }
            if footing <= 0 && shapes.contains(where: { $0.footing }) { return false }
            return true
        }

        /// What a kind of slot is worth, provisionally while it has never been
        /// measured.
        func height(of kind: Kind) -> Double {
            let measured: Double

            switch kind {
            case .row: measured = row
            case .heading: measured = heading
            case .footing: measured = footing
            }

            return measured > 0 ? measured : CollectionView.provisional
        }

        /// Whether a kind the list actually has is still waiting to be
        /// measured. A kind no group has needs nothing.
        func needs(_ kind: Kind) -> Bool {
            switch kind {
            case .row: return row <= 0 && shapes.contains { $0.rows > 0 }
            case .heading: return heading <= 0 && shapes.contains { $0.heading }
            case .footing: return footing <= 0 && shapes.contains { $0.footing }
            }
        }

        /// The first slot of a kind, wherever in the list it falls - what
        /// measures that kind for all of them.
        func first(_ kind: Kind) -> Int? {
            for (index, shape) in shapes.enumerated() {
                switch kind {
                case .heading where shape.heading:
                    return starts[index]

                case .row where shape.rows > 0:
                    return starts[index] + (shape.heading ? 1 : 0)

                case .footing where shape.footing:
                    return starts[index] + (shape.heading ? 1 : 0) + shape.rows

                default:
                    continue
                }
            }

            return nil
        }

        /// How many slots fit in a viewport - ONE where the list shows one at
        /// a time, whatever the arithmetic would otherwise make of it.
        func fits(in viewport: Double) -> Int {
            centres ? 1 : max(1, Int((viewport / step).rounded(.up)))
        }

        /// Which slot a position is, and whose.
        func slot(_ index: Int) -> Slot {
            let group = self.group { starts[$0] <= index }
            let shape = shapes[group]
            var offset = index - starts[group]

            if shape.heading {
                if offset == 0 { return Slot(group: group, kind: .heading, offset: 0) }
                offset -= 1
            }

            if offset < shape.rows { return Slot(group: group, kind: .row, offset: offset) }

            return Slot(group: group, kind: .footing, offset: 0)
        }

        /// Where a slot sits, in points down the list.
        func top(of index: Int) -> Double {
            let slot = slot(index)
            let shape = shapes[slot.group]
            var top = pad + tops[slot.group]

            if shape.heading && slot.kind != .heading { top += height(of: .heading) }
            if slot.kind == .row { top += Double(slot.offset) * step }

            if slot.kind == .footing && shape.rows > 0 {
                top += Double(shape.rows) * step - spacing
            }

            return top
        }

        /// The offset that brings a slot to where the list reads it: the top
        /// of the viewport, or its middle where one item is shown at a time.
        func offset(of index: Int) -> Double { top(of: index) - pad }

        /// An index the run actually has.
        func clamped(_ index: Int) -> Int { min(max(0, index), max(0, slots - 1)) }

        /// And which slot is at a position, which is the other direction.
        func slot(at y: Double) -> Int {
            let y = y - pad
            let group = self.group { tops[$0] <= y }
            let shape = shapes[group]
            var rest = y - tops[group]

            if shape.heading {
                if rest < height(of: .heading) { return starts[group] }
                rest -= height(of: .heading)
            }

            let row = min(max(0, Int(rest / step)), max(0, shape.rows - 1))

            return min(starts[group] + (shape.heading ? 1 : 0) + row, slots - 1)
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

    /// What the list shows, and how a row is described - by reference, so the
    /// state walk stops before the items.
    private final class Source {
        /// Every group, with its items and its templates.
        let groups: [CollectionGroup<Items, Id>]

        /// What the initializers were handed.
        init(groups: [CollectionGroup<Items, Id>]) {
            self.groups = groups
        }
    }

    /// Where a selection lives - and the type of the binding is the mode.
    private enum Selection {
        /// Nobody lent a binding, so the rows are not selectable.
        case none

        /// One row at a time, or none.
        case one(Binding<Id?>)

        /// As many as are tapped.
        case many(Binding<Set<Id>>)

        /// Whether this list is selectable at all.
        var isNone: Bool {
            if case .none = self { return true }
            return false
        }

        /// What a tap on a row means, which is the whole of the behaviour: the
        /// chosen row tapped again is deselected, MAUI's own contract for a
        /// single-selection list.
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

/// One group of a `CollectionView`: its rows, and what stands above and below them.
///
///     CollectionGroup(shelf.items) { item in
///         Label(item)
///     }
///     .id(shelf.name)
///     .header(Label(shelf.name))
///     .footer(Label("\(shelf.items.count) items"))
///
/// Not a view and not a control: a group is DATA the list lays out, so it has
/// no modifiers of its own beyond these. MAUI has no class for one either - a
/// grouped items source there is a list of lists, and whatever type those
/// lists are is the group.
///
/// A heading and a footing are slots in the same run as the rows, each kind
/// measured once - so give a group's heading the same shape as every other
/// group's, or state its height with `.heightRequest`.
public struct CollectionGroup<Items: RandomAccessCollection, Id: Hashable> {
    /// What this group shows, one row each.
    let items: Items

    /// Which part of an item is its identity.
    let path: KeyPath<Items.Element, Id>

    /// The row template.
    let row: (Items.Element) -> Element

    /// Who this group is among its siblings, when the author said.
    var name: String?

    /// What stands above the rows.
    var head: Element?

    /// And below them.
    var foot: Element?

    /// One row per item, the item its identity - the list's own initializer,
    /// one level down.
    ///
    /// - Parameters:
    ///   - items: What this group shows.
    ///   - content: The row template, run for the rows that can be seen.
    public init(
        _ items: Items,
        content: @escaping (Items.Element) -> Element
    ) where Items.Element: Hashable, Id == Items.Element {
        self.init(items, id: \.self, content: content)
    }

    /// The same, for items identified by the part `id` names.
    ///
    /// - Parameters:
    ///   - items: What this group shows.
    ///   - id: Which part of an item is its identity.
    ///   - content: The row template, run for the rows that can be seen.
    public init(
        _ items: Items,
        id: KeyPath<Items.Element, Id>,
        content: @escaping (Items.Element) -> Element
    ) {
        self.items = items
        self.path = id
        self.row = content
    }

    /// Who this group is, among its siblings - what its rows' identities are
    /// written under, so two groups may hold equal items and keep their own
    /// rows. A group that says nothing is identified by where it sits.
    public func id(_ value: some Hashable) -> Self {
        var copy = self
        copy.name = String(describing: value)
        return copy
    }

    /// What is drawn above the rows, scrolling with them.
    /// MAUI: GroupableItemsView.GroupHeaderTemplate, run here rather than
    /// bound.
    public func header(_ view: Element) -> Self {
        var copy = self
        copy.head = view
        return copy
    }

    /// And below them. MAUI: GroupableItemsView.GroupFooterTemplate.
    public func footer(_ view: Element) -> Self {
        var copy = self
        copy.foot = view
        return copy
    }

    /// The item at an offset - the one place a collection that is not an Array
    /// is indexed.
    func item(at offset: Int) -> Items.Element {
        items[items.index(items.startIndex, offsetBy: offset)]
    }
}

/// Which way a `CollectionView` runs, and which way the reader scrolls it.
public enum CollectionOrientation: Sendable {
    /// Down, which is what a list does unless it is told otherwise.
    case vertical

    /// Across.
    case horizontal
}
