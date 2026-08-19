// The library's own list.
//
//     LazyList(items) { item in
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
// decides, and a row that wants to be taller is squeezed - `.rowHeight()`
// states the number instead of measuring it. A row that scrolls out of the
// window leaves the tree, so its control goes and its own `@State` with it;
// what must outlive the window belongs in the page, keyed by the item, which
// is the rule a recycled list has anyway.
//
// WHAT IS NOT HERE. Nothing crosses the boundary that did not already: there
// is no node type, no Reconcile case, no fixture and no styles arm - a
// LazyList is a composed view like `FrameReader`, made of controls that
// already exist. Which is also why it works on every platform at once. A row
// that acts on a swipe is a `SwipeView` around the row, MAUI's own control,
// written in the template like any other view.

/// A list that describes only the rows it can see.
///
///     LazyList(files, id: \.path) { file in
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
/// **Rows are the same height.** The first row to be placed is measured and
/// every row is given that height, which is what lets the list know how tall
/// it is without describing anything. State the number with `.rowHeight()`
/// where the rows are taller than their content, or where measuring one of
/// them would be misleading.
///
/// **It needs a bounded height**, like any scroller: a `.heightRequest`, or a
/// star row of a Grid. In a bare VStack it is measured at the height of all
/// its rows and has nothing left to scroll.
///
/// **A row scrolled out of the window leaves the tree**, so its control goes
/// and the row's own `@State` with it. What must outlive the window - a
/// half-typed edit, whether a row is expanded - belongs in the page, keyed by
/// the item, which is the rule a recycled list asks for anyway.
///
/// Write this list's own modifiers - `.selection`, `.header`, `.rowHeight` -
/// before the ones every view has, since `.heightRequest` and its kind give
/// back the wrapper every composed view's modifiers give back.
public struct LazyList<Items: RandomAccessCollection, Id: Hashable>: ContentView {
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

    /// How tall the visible part of the list is, as layout settled it.
    @State private var viewport = 0.0

    /// Where the rows begin, under whatever header there is - what the scroll
    /// offset is measured against.
    @State private var rowsTop = 0.0

    /// The slot at the top of the viewport, which is what the window is drawn
    /// around.
    @State private var firstShown = 0

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

    /// The height the author stated, rather than one measured from a row.
    private var stated: Double?

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
    private static var margin: Int { 6 }

    /// What a slot is given while its own kind has never been measured - one
    /// render's worth of arithmetic, replaced by the measurement it makes.
    private static var provisional: Double { 44 }

    /// One row per item, the item its identity.
    ///
    ///     LazyList(rows) { row in
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
    ///     LazyList(files, id: \.path) { file in
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
        source = Source(groups: [LazyGroup(items, id: id, content: content)])
    }

    /// Rows under headings: the groups, each holding its rows and whatever
    /// stands above and below them.
    ///
    ///     LazyList(groups: shelves.map { shelf in
    ///         LazyGroup(shelf.items) { Label($0) }
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
    public init(groups: [LazyGroup<Items, Id>]) {
        source = Source(groups: groups)
    }

    /// The height to give every row, instead of measuring the first one.
    ///
    /// A list that says nothing measures a row and uses that, which is right
    /// while the rows describe their own height. State the number where they
    /// do not - a row of a fixed design, or one whose first item happens to be
    /// shorter than the rest. A group's heading and footing are measured
    /// either way.
    public func rowHeight(_ value: Double) -> Self {
        var copy = self
        copy.stated = value
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
    ///     LazyList(names) { name in
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
    ///     LazyList(names) { name in
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
    ///     LazyList(items) { Label($0) }
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
    ///     LazyList(items) { … }.rowHeight(44).assign(list)
    ///     Button("Top").onClicked { try await list.scrollTo(x: 0, y: 0) }
    ///
    /// A `ControlState<ScrollView>`, because that is what this list IS from the
    /// outside - so it takes a ScrollView's acts, offsets and all. A row's
    /// offset is its number times the row height, which is the other reason a
    /// list that means to be scrolled about states `.rowHeight()`; an offset
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

        var list = ScrollView {
            if let head {
                head
            }

            if plan.slots == 0 {
                if let empty {
                    empty
                }
            } else {
                placed(window, of: plan)
            }

            if let foot {
                foot
            }
        }

        if let scroller {
            list = list.assign(scroller)
        }

        return measuring(scrolling(list, of: plan))
    }

    /// The slots of the window, each where the arithmetic puts it.
    ///
    /// An AbsoluteLayout is the whole trick: its own height is stated - the
    /// sum over the groups - so the scroller knows how far it goes without a
    /// single row having been described, and every slot is placed by its
    /// number rather than by what stands above it.
    private func placed(_ window: [Int], of plan: Plan) -> Element {
        let tops = _rowsTop
        let ask = asking(plan)

        return AbsoluteLayout {
            ForEach(rows(window, of: plan), id: \.identity) { row in
                described(row)
            }
        }
        // -1 is MAUI's own "no request": while nothing has been measured the
        // slots placed measure themselves, and the heights arrive with them.
        .heightRequest(plan.settled ? plan.height : -1)
        .onFrameChanged { frame in
            if frame.y != tops.wrappedValue { tops.wrappedValue = frame.y }

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
        let measuring = plan.settled ? [] : Set(window)

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
    private func described(_ row: Placed) -> Element {
        var view = ModifiedContent(node: row.view.body)
            .absoluteLayoutBounds(
                Rect(0, row.y, 1, row.measures == nil ? row.height : AbsoluteLayout.autoSize))
            .absoluteLayoutFlags(.widthProportional)

        if let kind = row.measures {
            let heights = box(of: kind)

            view = view.onFrameChanged { frame in
                if frame.height > 0 && heights.wrappedValue <= 0 {
                    heights.wrappedValue = frame.height
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
        let tops = _rowsTop
        let firsts = _firstShown
        let ask = asking(plan)

        return list.addHandler(.scrollYChanged) {
            guard let y = EventBuffer.current.value()?.number else { return }
            guard plan.settled, plan.slots > 0 else { return }

            let top = plan.slot(at: y - tops.wrappedValue)
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
        let viewports = _viewport

        return {
            guard plan.settled, plan.slots > 0 else { return }

            let fits = plan.fits(in: viewports.wrappedValue)
            guard plan.slots - (firsts.wrappedValue + fits) <= threshold else { return }

            try await more()
        }
    }

    /// The scroller, hearing how big it is - which is how many rows fit.
    private func measuring(_ list: ScrollView) -> ScrollView {
        let viewports = _viewport

        return list.onFrameChanged { frame in
            if frame.height != viewports.wrappedValue { viewports.wrappedValue = frame.height }
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

        let fits = plan.fits(in: viewport > 0 ? viewport : screenful)
        let top = min(firstShown, plan.slots - 1)
        let first = max(0, top - Self.margin)
        let last = min(plan.slots, top + fits + Self.margin)

        return Array(first..<max(first + 1, last))
    }

    /// Where every group starts, in slots and in points - computed once per
    /// render, over the GROUPS rather than the rows.
    private var plan: Plan {
        Plan(
            shapes: source.groups.map {
                Shape(heading: $0.head != nil, rows: $0.items.count, footing: $0.foot != nil)
            },
            row: stated ?? measuredRow,
            heading: measuredHeading,
            footing: measuredFooting)
    }

    /// How tall the screen is, in the units a layout speaks - the standing
    /// answer to "how much of this list can possibly be visible" while the
    /// scroller's own measurement has not arrived. The number is generous by
    /// design: it costs a screenful of rows described and it is never short.
    private var screenful: Double {
        display.density > 0 ? display.height / display.density : 1_000
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

        /// Builds the sums, one addition per group.
        init(shapes: [Shape], row: Double, heading: Double, footing: Double) {
            var starts = [0]
            var tops = [0.0]

            for shape in shapes {
                starts.append(starts[starts.count - 1] + shape.slots)
                tops.append(tops[tops.count - 1]
                    + (shape.heading ? heading : 0)
                    + Double(shape.rows) * row
                    + (shape.footing ? footing : 0))
            }

            self.starts = starts
            self.tops = tops
            self.shapes = shapes
            self.row = row
            self.heading = heading
            self.footing = footing
        }

        /// How many slots the whole list is.
        var slots: Int { starts[starts.count - 1] }

        /// And how tall it is.
        var height: Double { tops[tops.count - 1] }

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

            return measured > 0 ? measured : LazyList.provisional
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
        func fits(in viewport: Double) -> Int {
            max(1, Int((viewport / height(of: .row)).rounded(.up)))
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
            var top = tops[slot.group]

            if shape.heading && slot.kind != .heading { top += height(of: .heading) }
            if slot.kind == .row { top += Double(slot.offset) * height(of: .row) }
            if slot.kind == .footing { top += Double(shape.rows) * height(of: .row) }

            return top
        }

        /// And which slot is at a position, which is the other direction.
        func slot(at y: Double) -> Int {
            let group = self.group { tops[$0] <= y }
            let shape = shapes[group]
            var rest = y - tops[group]

            if shape.heading {
                if rest < height(of: .heading) { return starts[group] }
                rest -= height(of: .heading)
            }

            let row = min(max(0, Int(rest / height(of: .row))), max(0, shape.rows - 1))

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
        let groups: [LazyGroup<Items, Id>]

        /// What the initializers were handed.
        init(groups: [LazyGroup<Items, Id>]) {
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

/// One group of a `LazyList`: its rows, and what stands above and below them.
///
///     LazyGroup(shelf.items) { item in
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
public struct LazyGroup<Items: RandomAccessCollection, Id: Hashable> {
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
