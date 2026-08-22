// The library's own carousel.
//
//     CarouselView(cards) { card in
//         CardView(card)
//     }
//     .position($shown)
//     .heightRequest(320)
//
// WHY IT EXISTS. MAUI's CarouselView is a platform recycler fed from an
// ObservableCollection the host owns, and a described template cannot keep
// what that recycler asks of it - the same boundary the list met, met again.
// What it did here: an item appended while the reader was swiping arrived as
// a collection RESET, so the carousel jumped back to position 0 instead of
// gaining a card, and enough sideways swipes in a row hung the app on Android.
// So this carousel asks the platform for nothing it cannot keep: a ScrollView,
// an AbsoluteLayout, and cards placed by arithmetic. Nothing on this side owns
// a collection the host mutates.
//
// HOW IT WORKS. The visible area is measured once, and a card is a FRACTION of
// it - three quarters by default, which is what leaves its neighbours showing
// at the edges. The run is the cards, the spacing between them, and a PAD at
// each end of exactly what is left over either side of a card: half of a
// viewport less half a card. That pad is what puts the first card in the
// middle at offset ZERO and the last one in the middle at the very end, so
// neither end can be scrolled past into emptiness - the run is as long as it
// has to be and not one point longer. The length is known from the count
// alone, which is what lets the cards themselves be described only where the
// reader is looking: the current one and its neighbours, and nothing else is
// built or sent.
//
// HOW IT SETTLES. It does not: the SCROLLER does, and the carousel only says
// where the cards are. A slot - a card and its gap - is the scroller's
// `.snapInterval`, so the offsets it may come to rest on are exactly the
// offsets that centre a card, and the platform's own deceleration is aimed at
// one of them before it begins. Nothing here decides anything about a
// movement, and nothing here hears about a finger.
//
// What the carousel hears is `.snapItem`: which card the scroller is nearest,
// which changes as the offset passes the halfway point between two of them -
// so a swipe is one message and one render per card, the card is named while
// the movement is still under way, and it is named by the same rounding that
// chose where to land. That number is the whole input: the window is the cards
// around it, and the position is it.
//
// WHAT IT COSTS, said out loud. Cards are UNIFORM, since their size is taken
// from the visible area rather than measured. There is no infinite loop: the
// run has two ends. A card outside the window leaves the tree, so its control
// goes and its own `@State` with it - what must outlive a swipe belongs in the
// page, keyed by the item.

/// One item at a time, swiped through - and the neighbours showing at the
/// edges.
///
///     @State private var shown = 0
///
///     CarouselView(cards, id: \.title) { card in
///         CardFace(card)
///     }
///     .position($shown)
///     .heightRequest(320)
///
/// The initializer IS the card template, run here - one card per item, the
/// item its identity. What is different from a stack of every card is how many
/// are described: the one in the middle and its neighbours, whatever the
/// collection's length.
///
/// **It needs a bounded size**, like any scroller: a `.heightRequest`, or a
/// star row of a Grid. A carousel is a window onto a run of cards, and a
/// window with no size shows all of them.
///
/// **The reader's swipe SETTLES on a card.** Wherever the offset stops, the
/// nearest card is brought to the middle - so the carousel is never left
/// between two of them.
///
/// **An IndicatorView is joined to one by a shared binding**, not by naming
/// it: both take a position, so one `@State` does the work.
///
///     CarouselView(cards) { … }.position($shown)
///     IndicatorView().count(cards.count).position(shown)
///
/// Write this carousel's own modifiers - `.position`, `.spacing`,
/// `.itemFraction` - before the ones every view has, since `.heightRequest`
/// and its kind give back the wrapper every composed view's modifiers give
/// back.
public struct CarouselView<Items: RandomAccessCollection, Id: Hashable>: ContentView {
    // The state is declared FIRST, deliberately: the boxes are adopted by
    // position in declaration order (Core/Stateful.swift), and a card template
    // stored below may build composed views carrying boxes of their own.

    /// How wide the visible area is. Zero until layout has settled.
    ///
    /// The two sides are kept as WIDTH and HEIGHT rather than as along-the-axis
    /// and across-it, because the axis can change without the frame doing: a
    /// carousel told to run down is the same rectangle, and it would wait for
    /// a report that never comes.
    @State private var width = 0.0

    /// And how tall.
    @State private var height = 0.0

    /// Which card is in the middle, where no binding was lent.
    @State private var shown = 0

    /// Which card the scroller says it is nearest, and so which card the
    /// window is drawn around. Written once per card crossed, never per frame.
    ///
    /// It is also what tells an ASSIGNED position from a reported one: the
    /// carousel glides to a position only when it differs from this, or a
    /// report would arm a glide that would report again.
    @State private var item = 0


    /// How long the run of cards MEASURED, which is not the same as how long
    /// it was asked to be: a scroller cannot be moved past content it has not
    /// been laid out with yet, so this is what says the offset can be reached.
    @State private var reach = 0.0

    /// The slot the last re-centring was made against - what says whether the
    /// GEOMETRY has moved since, which is the only thing a card has to be put
    /// back for.
    @State private var centred = 0.0

    /// The scroller this carousel is, so a settle can move it.
    @State private var scroller = ControlState<ScrollView>()

    /// The items and the card template, held BY REFERENCE - which is what
    /// stops the state walk here, the way a `CollectionView` stops it. See
    /// Core/Stateful.swift.
    private let source: Source

    /// Where the middle card is written, when an author lent a binding.
    private var pin: Binding<Int>?

    /// What runs when the middle card changes, beside any binding.
    private var moved: ValueEventHandler<Int>?

    /// How much of the visible area the middle card takes.
    private var fraction = 0.75

    /// The gap between one card and the next, in device units.
    private var gap = 12.0

    /// Which way the cards run.
    private var axis = CarouselOrientation.horizontal

    /// Whether the reader may swipe at all.
    private var swipes = true

    /// Whether a move this side makes glides or jumps.
    private var glides = true

    /// What stands in when there are no items at all.
    private var empty: Element?

    /// How close to the end is close enough to ask for more.
    private var threshold = -1

    /// What to run when it gets that close.
    private var more: EventHandler?

    /// How many cards either side are described anyway, so a swipe finds the
    /// next one already there and a fast one finds the one after it.
    private static var margin: Int { 2 }

    /// One card per item, the item its identity.
    ///
    ///     CarouselView(steps) { step in
    ///         Label(step)
    ///     }
    ///
    /// - Parameters:
    ///   - items: What the carousel shows, one card each.
    ///   - content: The card template, run for the cards in view.
    public init(
        _ items: Items,
        content: @escaping (Items.Element) -> Element
    ) where Items.Element: Hashable, Id == Items.Element {
        self.init(items, id: \.self, content: content)
    }

    /// The same, for items identified by the part `id` names - for items that
    /// are not `Hashable` whole or that repeat.
    ///
    ///     CarouselView(pages, id: \.number) { page in
    ///         PageFace(page)
    ///     }
    ///
    /// - Parameters:
    ///   - items: What the carousel shows, one card each.
    ///   - id: Which part of an item is its identity.
    ///   - content: The card template, run for the cards in view.
    public init(
        _ items: Items,
        id: KeyPath<Items.Element, Id>,
        content: @escaping (Items.Element) -> Element
    ) {
        source = Source(items: items, path: id, card: content)
    }

    /// Which card is in the middle, counting from 0 - and where a swipe writes
    /// the one it settled on. MAUI: CarouselView.Position, two-way here.
    ///
    ///     @State private var shown = 0
    ///
    ///     CarouselView(cards) { … }.position($shown)
    ///     Button("Next").onClicked { shown += 1 }
    ///
    /// Assigning it moves the carousel, gliding unless `.isScrollAnimated`
    /// says otherwise. A carousel nobody lends a binding to keeps the position
    /// itself and still settles on a card.
    public func position(_ binding: Binding<Int>) -> Self {
        var copy = self
        copy.pin = binding
        return copy
    }

    /// Another card came to the middle, and this is which one.
    /// MAUI: CarouselView.PositionChanged.
    ///
    /// Beside `.position($:)` rather than instead of it: the binding is where
    /// the number lives, and this is for what has to HAPPEN when it moves.
    public func onPositionChanged(_ handler: @escaping ValueEventHandler<Int>) -> Self {
        var copy = self
        copy.moved = handler
        return copy
    }

    /// How much of the visible area the middle card takes, from 0 to 1.
    ///
    ///     CarouselView(cards) { … }.itemFraction(0.9)
    ///
    /// Three quarters by default: the rest is the gap either side, which is
    /// where the neighbours show through and what says there is more to swipe
    /// to. A fraction rather than a length in device units, so the same
    /// carousel reads the same way on a phone and on a desktop.
    public func itemFraction(_ value: Double) -> Self {
        var copy = self
        copy.fraction = min(1, max(0.05, value))
        return copy
    }

    /// The gap between one card and the next, in device units. 12 by default.
    public func spacing(_ value: Double) -> Self {
        var copy = self
        copy.gap = max(0, value)
        return copy
    }

    /// Which way the cards run, and which way the reader swipes.
    /// Sideways unless this says otherwise.
    public func orientation(_ value: CarouselOrientation) -> Self {
        var copy = self
        copy.axis = value
        return copy
    }

    /// Whether the reader may swipe at all. MAUI: CarouselView.IsSwipeEnabled.
    ///
    /// A carousel that says no still moves when its position is assigned - it
    /// is the reader's hand that is stopped, not the carousel.
    public func isSwipeEnabled(_ value: Bool) -> Self {
        var copy = self
        copy.swipes = value
        return copy
    }

    /// Whether a move this side makes glides or jumps.
    /// MAUI: CarouselView.IsScrollAnimated. A settle after a swipe always
    /// glides: it is finishing a movement the reader started.
    public func isScrollAnimated(_ value: Bool) -> Self {
        var copy = self
        copy.glides = value
        return copy
    }

    /// What the carousel shows while it has no items at all.
    /// MAUI: ItemsView.EmptyView.
    public func emptyView(_ view: Element) -> Self {
        var copy = self
        copy.empty = view
        return copy
    }

    /// How close to the end the reader may get - counted in cards not yet
    /// swiped to - before `onRemainingItemsThresholdReached` runs.
    /// MAUI: ItemsView.RemainingItemsThreshold, and the same convention: -1,
    /// the default, means never; 0 asks as the last card arrives.
    public func remainingItemsThreshold(_ value: Int) -> Self {
        var copy = self
        copy.threshold = value
        return copy
    }

    /// Runs when the carousel has settled within `remainingItemsThreshold`
    /// cards of its end: append the next batch and the new cards are there
    /// when the reader arrives.
    ///
    ///     CarouselView(cards) { … }
    ///         .remainingItemsThreshold(1)
    ///         .onRemainingItemsThresholdReached { cards += nextBatch() }
    ///
    /// It can run again while the reader stays down there, so the handler
    /// guards on what it has already loaded.
    public func onRemainingItemsThresholdReached(_ handler: @escaping EventHandler) -> Self {
        var copy = self
        copy.more = handler
        return copy
    }

    /// The scroller, the cards placed inside it, and the handlers that settle
    /// it on one of them.
    public var content: Element {
        let plan = plan

        let scroll = ScrollView {
            if plan.count == 0 {
                if let empty {
                    empty
                }
            } else {
                placed(plan)
            }
        }
        // A carousel with nothing in it has nothing to scroll, and saying so
        // is what BOUNDS what stands in for the cards: left scrollable, the
        // empty view is measured against a run that is not there and a line of
        // text walks off both edges.
        .orientation(plan.count > 0 ? plan.scrolling : .neither)
        // Taking the swipe away is the scroller not HEARING the reader, not
        // the scroller being told to scroll neither way: a ScrollView told
        // that gives up where it stands, goes back to the beginning, and
        // refuses to be moved from this side either - so the carousel could
        // neither hold its card nor put it back.
        .inputTransparent(!swipes)
        .horizontalScrollBarVisibility(.never)
        .verticalScrollBarVisibility(.never)
        .assign(scroller)

        return watching(settling(measuring(scroll), plan), plan)
    }

    /// The cards of the window, each where the arithmetic puts it.
    ///
    /// The AbsoluteLayout is the whole trick: its length is stated - the slot
    /// count times a slot - so the scroller knows how far it goes without a
    /// single card having been described, and every card is placed by its
    /// number rather than by what stands before it.
    private func placed(_ plan: Plan) -> Element {
        let reaches = _reach
        let horizontal = plan.horizontal

        return AbsoluteLayout {
            ForEach(cards(plan), id: \.identity) { card in
                ModifiedContent(node: card.view.body)
                    .absoluteLayoutBounds(plan.bounds(at: card.origin))
                    .absoluteLayoutFlags(plan.flags)
            }
        }
        // -1 is MAUI's own "no request": until the scroller has been measured
        // there is no fraction to take of it, so the cards measure themselves
        // for that one render rather than being asked for a width of nothing.
        .widthRequest(plan.settled ? (plan.horizontal ? plan.extent : plan.across) : -1)
        .heightRequest(plan.settled ? (plan.horizontal ? plan.across : plan.extent) : -1)
        // The run's own measurement, which is what says a card can be brought
        // to the middle: asking the scroller for an offset it has not been
        // laid out to reach leaves it where it was, at the empty slot before
        // the first card. Measured on an Android phone, where the layout lands
        // a beat after the frame report the size came from and the carousel
        // opened on nothing at all.
        .onFrameChanged { frame in
            let measured = horizontal ? frame.width : frame.height

            if measured != reaches.wrappedValue { reaches.wrappedValue = measured }
        }
    }

    /// The cards to describe: the one the scroller says it is nearest, its
    /// neighbours, and wherever the position says the carousel is meant to be.
    ///
    /// The two are the same whenever the carousel is standing still. They part
    /// company for exactly as long as an assignment takes to arrive, and while
    /// a swipe is under way the REPORTED one is the truthful half - it names
    /// the card the scroller is heading for, half a card before it gets
    /// there.
    private func cards(_ plan: Plan) -> [Placed] {
        // TWO windows rather than one span: where the scroller says it is,
        // and where the position says it is meant to be. They are the same window whenever
        // the carousel is standing still, and a span between them would
        // describe every card in between - which for a carousel opened at its
        // five hundredth card is every card there is.
        var wanted = Set(Self.window(round: plan.clamped(item), of: plan))
        wanted.formUnion(Self.window(round: plan.clamped(current), of: plan))

        // Sorted, because a Set has no order and a message must be the same
        // bytes every run - Core/Wire.swift's rule.
        return wanted.sorted().map { index in
            let item = source.item(at: index)

            return Placed(
                identity: String(describing: item[keyPath: source.path]),
                view: source.card(item),
                origin: plan.origin(of: index))
        }
    }

    /// The cards around one of them, as far as the run goes.
    private static func window(round index: Int, of plan: Plan) -> Range<Int> {
        max(0, index - margin) ..< min(plan.count, index + margin + 1)
    }

    /// The scroller, hearing how big it is - which is how big a card is.
    private func measuring(_ scroll: ScrollView) -> ScrollView {
        let widths = _width
        let heights = _height

        return scroll.onFrameChanged { frame in
            if frame.width != widths.wrappedValue { widths.wrappedValue = frame.width }
            if frame.height != heights.wrappedValue { heights.wrappedValue = frame.height }
        }
    }

    /// The scroller, told where its cards are and heard when it changes which
    /// one it is nearest.
    ///
    /// Built out of LOCALS rather than `self`: this carousel holds a class,
    /// and a handler closure that captures one can leave this library's
    /// executor.
    private func settling(_ scroll: ScrollView, _ plan: Plan) -> ScrollView {
        let items = _item
        let settle = settling(plan)

        // A slot is the whole of what the scroller is told: the offsets that
        // centre a card are its multiples, counting from nothing, so the grid
        // starts where the content does.
        var gridded = scroll
        if plan.settled { gridded.node.props[.snapInterval] = .number(plan.slot) }

        return gridded.addHandler(.snapItemChanged) {
            guard let value = EventBuffer.current.value()?.number, plan.settled else { return }

            let index = plan.clamped(Int(value))
            guard index != items.wrappedValue else { return }

            // The window first, then the position: the window is what has to
            // be right before the next frame is drawn, and the position is
            // what tells anyone watching.
            items.wrappedValue = index
            _ = try await settle(index)
        }
    }

    /// Where the carousel is asked to be: the position an author assigned, and
    /// the size the layout settled on - both of which move the offset without
    /// the reader touching anything.
    private func watching(_ scroll: ScrollView, _ plan: Plan) -> Element {
        let items = _item
        let centres = _centred
        let scroller = scroller
        let glides = glides
        let middle = current
        let horizontal = plan.horizontal

        let recentre: EventHandler = {
            // The run is laid out at a new LENGTH every time the deck grows,
            // and a longer run moves no card: `origin` counts from the start
            // and knows nothing about the count. So the card in the middle is
            // put back only when the GEOMETRY moved - a first measurement, a
            // resize, a turn - and a deck that grew under a reader's finger is
            // left alone. Measured on Mac Catalyst: re-centring on the length
            // pulled a scroll in progress back onto the card it started from.
            guard plan.settled else { return }
            guard centres.wrappedValue != plan.slot else { return }

            centres.wrappedValue = plan.slot

            let target = plan.offset(of: plan.clamped(middle))

            try await scroller.scrollTo(
                x: horizontal ? target : 0,
                y: horizontal ? 0 : target,
                animated: false)
        }

        return scroll
            .onChanged(middle) {
                // A position the scroller REPORTED is where the carousel
                // already is, and gliding to it would report again - so only
                // a position somebody ASSIGNED moves anything. That is the
                // whole of what this carousel has to know about who moved it.
                guard plan.settled, plan.clamped(middle) != items.wrappedValue else { return }

                items.wrappedValue = plan.clamped(middle)

                let target = plan.offset(of: plan.clamped(middle))

                try await scroller.scrollTo(
                    x: horizontal ? target : 0,
                    y: horizontal ? 0 : target,
                    animated: glides)
            }
            // The run was laid out at a new length - the first time, after a
            // resize, after a turn, or because the deck grew - so the offset
            // that centred a card no longer does, and this is the first moment
            // the new one can be reached.
            .onChanged(reach, recentre)
    }

    /// What a settle does once it knows which card it landed on: writes the
    /// position wherever it lives, tells whoever asked, and asks for more
    /// items where the end is close.
    ///
    /// Answers whether the position MOVED - which is what says the watch on it
    /// is about to glide the carousel, so the settle need not.
    private func settling(_ plan: Plan) -> Settle {
        let pin = pin
        let shown = _shown
        let moved = moved
        let more = more
        let threshold = threshold
        let asks = threshold >= 0 && more != nil

        return { index in
            let was = pin?.wrappedValue ?? shown.wrappedValue
            let travelled = was != index

            if travelled {
                if let pin {
                    pin.wrappedValue = index
                } else {
                    shown.wrappedValue = index
                }

                if let moved {
                    try await moved(index)
                }
            }

            if asks, plan.count - 1 - index <= threshold, let more {
                try await more()
            }

            return travelled
        }
    }

    /// Which card is in the middle - the author's binding where there is one,
    /// and this carousel's own state where there is not.
    private var current: Int { pin?.wrappedValue ?? shown }

    /// The geometry, as this render's numbers make it.
    private var plan: Plan {
        Plan(
            count: source.count,
            viewport: axis == .horizontal ? width : height,
            across: axis == .horizontal ? height : width,
            fraction: fraction,
            gap: gap,
            horizontal: axis == .horizontal)
    }

    /// What a settle runs once it knows which card it landed on - the shape
    /// every handler here has, answering whether the position moved.
    private typealias Settle = nonisolated(nonsending) (Int) async throws -> Bool

    /// One card of the window, ready to be described.
    private struct Placed {
        /// Who it is, in the id namespace the author writes in.
        let identity: String

        /// What it shows.
        let view: Element

        /// Where it starts, in device units along the axis.
        let origin: Double
    }

    /// The items and their template, behind a class - which is what stops the
    /// Mirror walk that adopts state boxes from recursing through them.
    private final class Source {
        /// What the carousel shows.
        let items: Items

        /// Which part of an item is its identity.
        let path: KeyPath<Items.Element, Id>

        /// The card template.
        let card: (Items.Element) -> Element

        /// What the initializers were handed.
        init(items: Items, path: KeyPath<Items.Element, Id>, card: @escaping (Items.Element) -> Element) {
            self.items = items
            self.path = path
            self.card = card
        }

        /// How many cards there are.
        var count: Int { items.count }

        /// The item at an offset - the one place a collection that is not an
        /// Array is indexed.
        func item(at offset: Int) -> Items.Element {
            items[items.index(items.startIndex, offsetBy: offset)]
        }
    }

    /// Where every card sits, and which one an offset is nearest.
    ///
    /// The run is padded at each end by what is left over either side of a
    /// card - half a viewport less half a card - which is what makes the whole
    /// arithmetic fall out: card `i` is centred by an offset of `i` slots, the
    /// first at 0 and the last at the run's very end. Neither end has empty
    /// content behind it, and there is nothing to scroll past.
    private struct Plan {
        /// How many cards there are.
        let count: Int

        /// How long the visible area is along the axis.
        let viewport: Double

        /// And across it.
        let across: Double

        /// How much of the viewport one card takes.
        let fraction: Double

        /// The gap between two cards.
        let gap: Double

        /// Whether the cards run sideways.
        let horizontal: Bool

        /// How long one card is along the axis.
        var card: Double { viewport * fraction }

        /// A card and the gap after it - the step from one card to the next.
        var slot: Double { card + gap }

        /// What is left over either side of a card, which is the pad at each
        /// end of the run.
        var pad: Double { (viewport - card) / 2 }

        /// How long the whole run is: every card, the gaps between them, and
        /// the two pads.
        var extent: Double { count > 0 ? Double(count - 1) * slot + viewport : 0 }

        /// Whether there is anything to place and anything to place it in.
        var settled: Bool { count > 0 && viewport > 0 }

        /// Which way the scroller scrolls.
        var scrolling: ScrollOrientation { horizontal ? .horizontal : .vertical }

        /// Which parts of a card's bounds are fractions of the layout: the
        /// card's own length is in device units, and the side across the axis
        /// is the whole of it.
        var flags: AbsoluteLayoutFlags { horizontal ? .heightProportional : .widthProportional }

        /// Where a card starts, in device units along the axis.
        func origin(of index: Int) -> Double { pad + Double(index) * slot }

        /// Where a card is placed, in the rectangle an AbsoluteLayout reads.
        func bounds(at origin: Double) -> Rect {
            horizontal ? Rect(origin, 0, card, 1) : Rect(0, origin, 1, card)
        }

        /// The offset that puts a card in the middle of the visible area -
        /// which the pads make one slot per card, counting from nothing.
        func offset(of index: Int) -> Double { Double(index) * slot }

        /// An index the run actually has.
        func clamped(_ index: Int) -> Int { min(max(0, index), max(0, count - 1)) }
    }
}

/// Which way a `CarouselView` runs, and which way the reader swipes it.
///
/// Two cases and no grid: a carousel shows one card at a time, so there is
/// nothing for a span to mean.
public enum CarouselOrientation: Sendable {
    /// Sideways, which is what a carousel does unless it is told otherwise.
    case horizontal

    /// Up and down.
    case vertical
}
