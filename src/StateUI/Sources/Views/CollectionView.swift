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
// control, which is what the `///` below says out loud. Everything else in the
// library that wears a MAUI name IS MAUI's, so this is the one exception worth
// naming.
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

/// Whether one item's measurement answers for all of them.
/// MAUI: ItemSizingStrategy.
///
/// This library's own list works out where a slot sits by arithmetic rather
/// than by laying every row out, so how much of the list it has to measure is
/// the one thing that decides what a long list costs.
public enum ItemSizingStrategy: Sendable {
    /// One item is measured and every other one is given the same size.
    ///
    /// Where a slot sits is then one multiplication, so a list of a hundred
    /// thousand rows costs what a list of ten does. Exact whenever the rows
    /// are alike, which is what a list usually is.
    case measureFirstItem

    /// Every item is measured, and each one is its own size.
    ///
    /// What a feed of posts, a chat or a list of cards needs. The price is
    /// that every item is walked to work out where the next one goes, so it
    /// is for a list of tens or hundreds; a row that has never been on screen
    /// has never been measured, and the length of the run is an estimate until
    /// it has.
    case measureAllItems
}

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
    // The state is declared FIRST, deliberately: a box is adopted by its
    // PATH, which is the stored property's own name at every level
    // (Core/Stateful.swift), and a header stored below may be a composed view
    // carrying boxes of its own. Declared above them, this list's own are
    // reached before anything it is furnished with.

    /// What the first placed row measured - the height every row is given, and
    /// the number the whole geometry is computed from. Zero until it settles.
    @State private var measuredRow = 0.0

    /// The same for a group's heading, measured once and answering for all of
    /// them.
    @State private var measuredHeading = 0.0

    /// And for a group's footing.
    @State private var measuredFooting = 0.0

    /// What each row measured, by its identity - filled only where the list is
    /// told to measure every item.
    ///
    /// BY IDENTITY, never by position: a row inserted at the top would
    /// otherwise hand every row below it the height of its neighbour, and the
    /// whole list would shuffle. A row that has never been shown is not in
    /// here at all and is worth whatever `Plan.estimate` says.
    @State private var measuredRows: [String: Double] = [:]

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

    /// How long the run MEASURED, which is not the same as how long it was
    /// asked to be: a scroller cannot be moved past content it has not been
    /// laid out with yet, so this is what says an offset can be reached.
    ///
    /// Along the CURRENT axis, so a turn forgets it - a run the same length
    /// both ways would otherwise read as never laid out anew - and the
    /// layout's report along the new axis is what fills it again.
    @State private var reach = 0.0

    /// Whether every row is measured, or one row answers for all of them.
    private var sizing = ItemSizingStrategy.measureFirstItem

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

    /// How many rows above and below the visible ones are described anyway, so
    /// an ordinary flick finds them already there. Rows are cheap here and a
    /// blank row is not, which is what decides the number.
    private static var span: Int { 6 }

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

    /// Whether one item's measurement answers for all of them, or every item
    /// is measured on its own. MAUI: CollectionView.ItemSizingStrategy.
    ///
    ///     CollectionView(posts) { post in … }
    ///         .itemSizingStrategy(.measureAllItems)
    ///
    /// The default measures the FIRST item and gives every other one the same
    /// size, which is exact whenever the rows are alike and is what makes a
    /// list of a hundred thousand rows cost the same as a list of ten: where a
    /// slot sits is one multiplication.
    ///
    /// `.measureAllItems` lets every row be its own size - a feed whose posts
    /// are a line or a paragraph, a chat, a list of cards. The price is that
    /// every item is walked to work out where the next one goes, so it is for
    /// a list of tens or hundreds and not for one of thousands. A row that has
    /// not been on screen yet has never been measured, so the length of the
    /// run is an estimate until it has; the rows already ABOVE the reader are
    /// measured, which is why nothing under them ever shifts.
    ///
    /// - Parameter value: which strategy to use.
    /// - Returns: the list, measuring that way.
    public func itemSizingStrategy(_ value: ItemSizingStrategy) -> Self {
        var copy = self
        copy.sizing = value
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

    /// The scroller, the slots placed inside it, and the measurements that
    /// decide which slots those are.
    public var content: Element {
        let plan = plan
        let window = window(of: plan)
        let vertical = axis == .vertical

        var list = ScrollView {
            // AN UNFURNISHED LIST IS ONE BRANCH WHICHEVER WAY IT RUNS, and the
            // branch is what the rows are kept BY: two branches are two
            // elements even where they build the same control, so a list
            // turned round would throw its layout away and build every row it
            // is showing a second time. There is nothing to turn round here -
            // the rows are placed by arithmetic either way.
            if head == nil && foot == nil {
                body(window, of: plan)
            } else if vertical {
                if let head { head }

                body(window, of: plan)

                if let foot { foot }
            } else {
                // A list that runs ACROSS and is furnished puts its three
                // parts in a stack of its own, because a scroller given
                // several children stacks them DOWNWARDS - which would hang a
                // horizontal list's rows under its header instead of after it.
                HStack {
                    if let head { head }

                    body(window, of: plan)

                    if let foot { foot }
                }
                .spacing(0)
            }
        }
        // A list with nothing in it has nothing to scroll, and saying so is
        // what BOUNDS whatever stands in for the rows: left scrollable, an
        // empty view is measured against a run that is not there and a line of
        // text walks off both edges.
        .orientation(plan.slots == 0 ? .neither : (vertical ? .vertical : .horizontal))
        // THE LIST'S OWN NUMBERS ARRIVE, they do not travel. Everything this
        // control writes about itself - how long the run is, how far apart its
        // stops are, where a slot sits - is arithmetic answering a measurement
        // or a scroll, and a value still on its way would be read as the law by
        // whatever asks next. What the AUTHOR wrote inside a row travels like
        // anything else: this says nothing about the rows themselves.
        .motion(.none)

        if let scroller {
            list = list.assign(scroller)
        }

        // A grid of one item, so a throw ends with an item at the edge. Only
        // where every slot IS an item: a heading is a different size, and the
        // rows after one stand off any fixed step.
        if snaps, plan.settled, plan.uniform {
            list = list.snapInterval(plan.step, from: rowsStart)
        }

        return measuring(offset(list, of: plan))
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
        // The run's own length and the window's placement are answers to a
        // measurement, not values a reader watches change. See the scroller.
        .motion(.none)
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
        .widthRequest(vertical ? -1 : (plan.settled ? plan.height : -1))
        .onFrameChanged { frame in
            let start = vertical ? frame.y : frame.x

            if start != starts.wrappedValue { starts.wrappedValue = start }

            // How long the run was LAID OUT, which is not how long it was
            // asked to be: a scroller cannot be moved past content it has not
            // been laid out with yet, so this is what says an offset can be
            // reached. Measured on an Android phone, where the layout lands a
            // beat after the frame report the size came from and a run
            // opened on nothing at all.
            let measured = vertical ? frame.height : frame.width

            if measured != reaches.wrappedValue { reaches.wrappedValue = measured }

            // This frame is the CONTENT's, so it changes when the list grows -
            // which is the other moment "am I near the end" can become true.
            try await ask?()
        }
    }

    /// What a slot is CALLED - the one place the answer is written, so the
    /// rows the window describes and the sizes the plan reads are filed under
    /// the same name.
    private func identity(group: Int, kind: Kind, offset: Int) -> String {
        let shape = source.groups[group]

        if kind != .row {
            return "\(shape.name ?? "\(group)")/\(kind.suffix)"
        }

        let item = shape.item(at: offset)
        let own = String(describing: item[keyPath: shape.path])

        // Under its group, so two groups may hold equal items and keep their
        // own rows. A group that says nothing is identified by where it SITS,
        // exactly as its heading is - and a list of one group prefixes
        // nothing, its rows being the only ones there are.
        let under = source.groups.count > 1 ? (shape.name ?? "\(group)") : shape.name

        return under.map { "\($0)/\(own)" } ?? own
    }

    /// How long every slot of the list is, in order - what a list that
    /// measures each item is placed by.
    ///
    /// A row that has never been on screen has never been measured, so it is
    /// worth whatever one row is worth; the rows the reader has already
    /// passed ARE measured, which is why nothing above them ever shifts as the
    /// rest of the list is worked out.
    private func sizes(_ estimate: Double) -> [Double] {
        var all: [Double] = []
        all.reserveCapacity(source.groups.count * 8)

        for (index, group) in source.groups.enumerated() {
            if group.head != nil {
                all.append(measured(index, .heading, 0) ?? guess(measuredHeading))
            }

            for offset in 0..<group.items.count {
                all.append(measured(index, .row, offset) ?? estimate)
            }

            if group.foot != nil {
                all.append(measured(index, .footing, 0) ?? guess(measuredFooting))
            }
        }

        return all
    }

    /// What one slot measured, or nothing when it has never been shown.
    private func measured(_ group: Int, _ kind: Kind, _ offset: Int) -> Double? {
        measuredRows[identity(group: group, kind: kind, offset: offset)]
    }

    /// A measurement, or the standing guess while there is none.
    private func guess(_ value: Double) -> Double {
        value > 0 ? value : CollectionView.provisional
    }

    /// Every slot of the window, with where it sits and who it is.
    ///
    /// Each position costs a binary search over the GROUPS, which is nothing:
    /// a flat list has one group and a hundred groups are seven comparisons.
    private func rows(_ window: [Int], of plan: Plan) -> [Placed] {
        // While a kind has never been measured, every slot placed is one that
        // measures itself - the window IS that list - and it carries the only
        // frame subscription there will ever be. A list that measures EVERY
        // item keeps that subscription on every row it describes, for ever:
        // each row is its own size, and a row whose content changes is a new
        // size to be told about.
        let measuring = sizing == .measureAllItems
            ? Set(window)
            : (plan.settled ? [] : Set(window))

        return window.compactMap { index in
            let slot = plan.slot(index)
            let group = source.groups[slot.group]

            switch slot.kind {
            case .heading, .footing:
                guard let view = slot.kind == .heading ? group.head : group.foot else { return nil }

                return Placed(
                    identity: identity(group: slot.group, kind: slot.kind, offset: 0),
                    view: view,
                    chooses: nil,
                    y: plan.top(of: index),
                    height: plan.height(of: slot.kind),
                    measures: measuring.contains(index) ? slot.kind : nil)

            case .row:
                let item = group.item(at: slot.offset)

                return Placed(
                    identity: identity(group: slot.group, kind: .row, offset: slot.offset),
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
        // A row that measures itself is laid out at its OWN size, which is
        // the whole of what "every item is its own size" means: the plan
        // places the next row where this one's report says this one ended.
        let length = row.measures == nil ? row.height : AbsoluteLayout.autoSize

        var view = ModifiedContent(node: row.view.body)
            .absoluteLayoutBounds(
                vertical ? Rect(0, row.y, 1, length) : Rect(row.y, 0, length, 1))
            // The side ACROSS the axis is the whole of the list; the side along
            // it is the item's own, in device units.
            .absoluteLayoutFlags(vertical ? .widthProportional : .heightProportional)


        if let kind = row.measures {
            let sizes = box(of: kind)
            let all = _measuredRows
            let each = sizing == .measureAllItems
            let name = row.identity

            view = view.onFrameChanged { frame in
                let measured = vertical ? frame.height : frame.width

                guard measured > 0 else { return }

                // The kind's own measurement is still taken, whichever
                // strategy this is: it is what says the arithmetic has
                // SETTLED, and what a row nobody has shown yet is worth.
                if sizes.wrappedValue <= 0 { sizes.wrappedValue = measured }

                if each, all.wrappedValue[name] != measured {
                    all.wrappedValue[name] = measured
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
    /// The report is where the WINDOW comes from, and the state is written only
    /// when the slot at the top actually changes - so a flick that crosses four
    /// rows renders four times rather than once per scroll tick.
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
        let sizes = [_measuredRow, _measuredHeading, _measuredFooting]
        let reaches = _reach
        let measures = stated == nil

        return list
            .onFrameChanged { frame in
                if frame.width != widths.wrappedValue { widths.wrappedValue = frame.width }
                if frame.height != heights.wrappedValue { heights.wrappedValue = frame.height }
            }
            // A slot was measured ALONG the way the list ran, so a list turned
            // to run the other way holds three numbers that are now about the
            // other side of it. They are measured again rather than carried: an
            // item's height is not its width. A list TOLD its item's length
            // measures none of them and has nothing to put back.
            .onChanged(axis) {
                // EVERY list forgets what the run reached: it was taken along
                // the axis that has just gone, and a square viewport makes it
                // the same number on either one, so carrying it would read as
                // the turn never having happened. The layout's report along the
                // new axis fills it again.
                if reaches.wrappedValue != 0 { reaches.wrappedValue = 0 }

                guard measures else { return }

                for size in sizes where size.wrappedValue != 0 {
                    size.wrappedValue = 0
                }
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

        guard plan.settled else {
            return [Kind.heading, .row, .footing]
                .filter { plan.needs($0) }
                .compactMap { plan.first($0) }
                .sorted()
        }

        let measured = axis == .vertical ? measuredHeight : measuredWidth
        let fits = plan.fits(in: measured > 0 ? measured : screenful)
        let span = CollectionView.span
        let top = min(firstShown, plan.slots - 1)
        let first = max(0, top - span)
        let last = min(plan.slots, top + fits + span)

        return Array(first..<max(first + 1, last))
    }

    /// Where every group starts, in slots and in points - computed once per
    /// render, over the GROUPS rather than the rows.
    private var plan: Plan {
        let row = stated ?? measuredRow

        return Plan(
            shapes: source.groups.map {
                Shape(heading: $0.head != nil, rows: $0.items.count, footing: $0.foot != nil)
            },
            row: row,
            heading: measuredHeading,
            footing: measuredFooting,
            sizes: sizing == .measureAllItems ? sizes(guess(row)) : nil)
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

        /// Where every SLOT sits, then the whole length - built only where the
        /// list measures each item, and nil where one row answers for all.
        ///
        /// It is the whole of what a list of unequal rows costs: one number
        /// per slot rather than one per group, walked once when the plan is
        /// built and read in one lookup afterwards.
        let each: [Double]?

        /// Builds the sums, one addition per group.
        init(
            shapes: [Shape],
            row: Double,
            heading: Double,
            footing: Double,
            sizes: [Double]?
        ) {
            var starts = [0]
            var tops = [0.0]
            let run = { (rows: Int) in Double(rows) * row }

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

            // One running total per slot, and the length after the last of
            // them - the same sums the groups get, one level finer.
            if let sizes = sizes {
                var running = [0.0]
                running.reserveCapacity(sizes.count + 1)

                for (index, size) in sizes.enumerated() {
                    running.append(running[index] + size)
                }

                each = running
            } else {
                each = nil
            }
        }

        /// The step from one row to the next.
        var step: Double { height(of: .row) }

        /// How many slots the whole list is.
        var slots: Int { starts[starts.count - 1] }

        /// Whether every slot is an ITEM of one size - no heading and no
        /// footing anywhere, and every row worth the same - so the run is one
        /// size all the way down and a fixed grid describes it.
        var uniform: Bool {
            each == nil && shapes.allSatisfy { !$0.heading && !$0.footing }
        }

        /// And how tall it is.
        var height: Double {
            if let each = each {
                return max(0, each[each.count - 1])
            }

            return tops[tops.count - 1]
        }

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

        /// How many slots fit in a viewport.
        ///
        /// Where the rows are unequal it is counted off the SHORTEST of them,
        /// so the answer is never short: a window a row too small is a band of
        /// nothing at the bottom of the screen.
        func fits(in viewport: Double) -> Int {
            let shortest = shortestStep

            return max(1, Int((viewport / max(shortest, 1)).rounded(.up)))
        }

        /// The smallest step from one slot to the next, which is what a window
        /// has to be counted in.
        private var shortestStep: Double {
            guard let each = each, each.count > 1 else { return step }

            var least = Double.greatestFiniteMagnitude

            for index in 1..<each.count {
                least = min(least, each[index] - each[index - 1])
            }

            return least
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
            if let each = each {
                return each[min(max(0, index), each.count - 1)]
            }

            let slot = slot(index)
            let shape = shapes[slot.group]
            var top = tops[slot.group]

            if shape.heading && slot.kind != .heading { top += height(of: .heading) }
            if slot.kind == .row { top += Double(slot.offset) * step }

            if slot.kind == .footing && shape.rows > 0 {
                top += Double(shape.rows) * step
            }

            return top
        }

        /// An index the run actually has.
        func clamped(_ index: Int) -> Int { min(max(0, index), max(0, slots - 1)) }

        /// And which slot is at a position, which is the other direction.
        func slot(at y: Double) -> Int {
            if let each = each {
                // The last slot whose top is at or before the position, found
                // the way the groups are: a list of unequal rows may be as
                // long as it likes.
                var low = 0
                var high = each.count - 2

                while low < high {
                    let middle = (low + high + 1) / 2
                    if each[middle] <= y { low = middle } else { high = middle - 1 }
                }

                return clamped(low)
            }

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
