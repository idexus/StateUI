// The library's own carousel, which is the library's own list wearing one
// particular shape.
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
//
// WHAT IT IS. A `CollectionView` running across, with its items taken as a
// FRACTION of the visible area and CENTRED - which is one call, `centred(_:)`,
// and every difference between a carousel and a list follows from it: the run
// is padded at each end so the first card is centred at an offset of nothing
// and the last at the very end; one card fits, so the window is drawn around
// the card the reader is ON; the scroller is heard as WHICH CARD it is
// nearest rather than as an offset; and the window waits for the movement to
// stop unless a swipe outruns it, a card being a control the platform has to
// build and building one under a finger being seen.
//
// So the arithmetic is written once. What is left here is the FACE: MAUI's
// names for a carousel's properties, and the defaults that make a list of
// cards read as a carousel - three quarters of the view a card, twelve
// between them, half of the platform's own throw.
//
// WHAT IT COSTS, said out loud. Cards are UNIFORM, since their size is taken
// from the visible area rather than measured. There is no infinite loop: the
// run has two ends. A card outside the window leaves the tree, so its control
// goes and its own `@State` with it - what must outlive a swipe belongs in the
// page, keyed by the item.

/// One item at a time, swiped through - and the neighbours showing at the
/// edges.
///
/// **This is the library's own, not MAUI's control** - written in Swift, and
/// carrying MAUI's name because that is what a reader looks under. It IS a
/// `CollectionView`, this library's own list, told to show one item at a time:
/// there is no platform recycler under it and nothing of it on the other side
/// of the boundary. Its properties are MAUI's names for a carousel's, because
/// those are the names a reader already knows; what is behind them is this
/// library's arithmetic.
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

    /// Which card is in the middle, where no binding was lent.
    @State private var shown = 0

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

    /// How much of the platform's own throw a swipe keeps.
    private var carry = 0.5

    /// The most cards one swipe may cross. Zero is as many as it carries.
    private var limit = 0

    /// How close to the end is close enough to ask for more.
    private var threshold = -1

    /// What to run when it gets that close.
    private var more: EventHandler?

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

    /// How far a swipe CARRIES, as a fraction of what the platform would throw
    /// a scroller on its own. Half, unless this says otherwise.
    ///
    ///     CarouselView(cards) { … }.momentum(0.35)
    ///
    /// A touch platform throws a scroller a long way, which is what makes a
    /// long list quick to cross and what makes a strip of cards feel loose: at
    /// 1 an ordinary flick crosses several cards. Less is a carousel that
    /// answers the same flick with the next card; more is one that runs on.
    /// It scales the platform's OWN throw rather than replacing it, so a hard
    /// swipe still goes further than a gentle one.
    public func momentum(_ fraction: Double) -> Self {
        var copy = self
        copy.carry = max(0, fraction)
        return copy
    }

    /// The most cards one swipe may cross. Nothing is the default, and means
    /// as many as the throw carries.
    ///
    ///     CarouselView(cards) { … }.snapsAtMost(1)
    ///
    /// A hard swipe crosses several cards, which is right for a deck somebody is
    /// looking THROUGH and wrong for one they are stepping through - a sign-up
    /// with four steps, a tutorial. At `1` every swipe moves exactly one card,
    /// however hard it was thrown, and the card still arrives the way any other
    /// swipe brings one.
    ///
    /// It is counted from where the FINGER LANDED rather than from where it let
    /// go, so a drag most of the way to the next card and a throw on the end of
    /// it cannot add up to two.
    ///
    /// - Parameter cards: how many cards a swipe may cross. Zero, or less, is
    ///   no limit.
    public func snapsAtMost(_ cards: Int) -> Self {
        var copy = self
        copy.limit = max(0, cards)
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

    /// The list this carousel is, told to show one card at a time.
    public var content: Element {
        var cards = CollectionView(source.items, id: source.path, content: source.card)
            .orientation(axis == .horizontal ? .horizontal : .vertical)
            .itemFraction(fraction)
            .itemSpacing(gap)
            .centred(true)
            .momentum(carry)
            .snapsAtMost(limit)
            .position(pin ?? $shown, glides: glides)
            .remainingItemsThreshold(threshold)

        if let moved {
            cards = cards.onPositionChanged(moved)
        }

        if let empty {
            cards = cards.emptyView(empty)
        }

        if let more {
            cards = cards.onRemainingItemsThresholdReached(more)
        }

        // Taking the swipe away is the scroller not HEARING the reader, not
        // the scroller being told to scroll neither way: a ScrollView told
        // that gives up where it stands, goes back to the beginning, and
        // refuses to be moved from this side either - so the carousel could
        // neither hold its card nor put it back.
        return cards.inputTransparent(!swipes)
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
        init(
            items: Items,
            path: KeyPath<Items.Element, Id>,
            card: @escaping (Items.Element) -> Element
        ) {
            self.items = items
            self.path = path
            self.card = card
        }
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
