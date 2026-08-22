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
// HOW IT SETTLES. The platform reports the offset as it moves, and the
// carousel takes over when it STOPS being moved - a report that no other
// report follows for a moment, which is what stands in for the reader's finger
// lifting: no touch crosses this boundary, and a hand that is moving reports.
// What it does then is one movement, not a snap: it reads the SPEED the offset
// was travelling at, works out where a glide shedding that speed evenly would
// come to rest, and takes the card nearest THAT - never more than one card on
// from where the movement started, so a hard flick is a card and not five. A
// speed too low to mean anything is a reader who parked the carousel rather
// than throwing it, and lands on the card under it; a speed that means
// something but is small is carried at a floor, so the movement is always
// deliberate. Then the offset is walked to that card's middle BY HAND, over
// the same 400 ms whatever the distance, easing out - so the braking is one
// length and one shape every time. A report that lands far from what the walk
// asked for is the reader taking the carousel back, and the walk gives up.
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

    /// Where the offset was last reported. Written by every report and read by
    /// nothing that builds, so a whole drag costs no renders at all.
    @State private var offset = 0.0

    /// How fast it was travelling when it was last reported, in device units a
    /// second and SIGNED - which is what says where a movement was going.
    @State private var speed = 0.0

    /// Where the offset was when this movement began - what says which way the
    /// movement AS A WHOLE went, and so whether the last report is part of it.
    @State private var began = 0.0

    /// When that report arrived, which is what a speed is measured against.
    @State private var reportedAt: ContinuousClock.Instant?

    /// What the carousel's own walk last asked the scroller for - and nothing
    /// at all while the offset is the reader's.
    @State private var driving: Double?

    /// Which report a settle is waiting on. A newer one takes the ticket, and
    /// the older settle finds it gone and drops out.
    @State private var ticket = 0

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
    /// stops the state walk here, the way a `LazyList` stops it. See
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

    /// How many cards either side of the middle one are described anyway, so a
    /// swipe finds its neighbour already there.
    private static var margin: Int { 1 }

    /// How long the offset must stay unreported before the carousel takes
    /// over, in milliseconds - the quiet a stopped offset leaves behind, which
    /// is what stands in for a finger lifting.
    private static var settleQuiet: Int { 60 }

    /// How long the walk to a card's middle takes, in milliseconds, whatever
    /// the distance - so the braking is one length every time.
    private static var settleTime: Int { 400 }

    /// How often the walk asks the scroller for a new offset, in milliseconds.
    private static var settleFrame: Int { 16 }

    /// The slowest a movement may be said to be TRAVELLING, in device units a
    /// second: below it the reader parked the carousel rather than throwing
    /// it, and it lands on the card it is over.
    private static var settleStill: Double { 20 }

    /// And the slowest one that IS travelling is carried at, so a small flick
    /// still reaches the next card instead of falling back.
    private static var settleFloor: Double { 900 }

    /// How far a report may be from what the walk asked for before it is the
    /// reader taking the carousel back, in device units.
    private static var settleDrift: Double { 40 }

    /// How far from a card's centre the offset may already be for the settle
    /// to leave it alone, in device units. Without it the scroll a settle
    /// makes would report an offset that settles again.
    private static var settleTolerance: Double { 0.5 }

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

    /// The cards to describe: the middle one and its neighbours, each with
    /// where it sits and who it is.
    private func cards(_ plan: Plan) -> [Placed] {
        let middle = min(max(0, current), plan.count - 1)
        let first = max(0, middle - Self.margin)
        let last = min(plan.count, middle + Self.margin + 1)

        return (first..<last).map { index in
            let item = source.item(at: index)

            return Placed(
                identity: String(describing: item[keyPath: source.path]),
                view: source.card(item),
                origin: plan.origin(of: index))
        }
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

    /// The scroller, hearing where it has been scrolled to - and settling on
    /// the nearest card once the reader has let go.
    ///
    /// Built out of LOCALS rather than `self`: this carousel holds a class,
    /// and a handler closure that captures one can leave this library's
    /// executor.
    private func settling(_ scroll: ScrollView, _ plan: Plan) -> ScrollView {
        let offsets = _offset
        let speeds = _speed
        let begans = _began
        let times = _reportedAt
        let tickets = _ticket
        let drivings = _driving
        let scroller = scroller
        let settle = settling(plan)
        let horizontal = plan.horizontal

        return scroll.addHandler(horizontal ? .scrollXChanged : .scrollYChanged) {
            guard let value = EventBuffer.current.value()?.number, plan.settled else { return }

            let previous = offsets.wrappedValue

            // A report while the carousel is walking the offset itself is that
            // walk coming back - unless it is a long way from what the walk
            // asked for, which is the reader taking the carousel back.
            if let asked = drivings.wrappedValue {
                offsets.wrappedValue = value

                guard abs(value - asked) > Self.settleDrift else { return }

                drivings.wrappedValue = nil
            }

            let now = ContinuousClock.now

            // Nothing to measure against is a movement STARTING, and where it
            // starts is what its direction is read against.
            if times.wrappedValue == nil { begans.wrappedValue = previous }

            speeds.wrappedValue = Self.speed(
                of: value - previous, since: times.wrappedValue, at: now)
            offsets.wrappedValue = value
            times.wrappedValue = now

            // EVERY report takes the ticket, which is what cancels the settle
            // the report before it armed: while the offset is moving there is
            // always a newer report, so the only one that survives its own
            // wait is the one armed by the LAST report of a movement.
            let ticket = tickets.wrappedValue + 1
            tickets.wrappedValue = ticket

            try await Task.sleep(for: .milliseconds(Self.settleQuiet))
            guard tickets.wrappedValue == ticket else { return }

            let start = offsets.wrappedValue

            // A speed pointing the other way from the movement as a whole is
            // not the movement: past an end the platform SPRINGS the offset
            // back, and the last report of a hard flick is that spring rather
            // than the throw. Carried, it takes the carousel a card BACKWARDS
            // from where the flick landed - measured on Mac Catalyst, and it
            // read as a carousel that could not make up its mind.
            let net = start - begans.wrappedValue
            let carried = net * speeds.wrappedValue < 0 ? 0 : speeds.wrappedValue

            let index = plan.landing(from: start, travelling: Self.travel(at: carried))
            let target = plan.offset(of: index)

            // Left on a card already: there is a position to write and nothing
            // to walk.
            guard abs(target - start) > Self.settleTolerance else {
                _ = try await settle(index)
                return
            }

            // The carousel owns the movement from here, which is what keeps
            // the watch on the position from starting a second one - and the
            // POSITION is written before the walk, so the dots move as the
            // carousel decides rather than when it arrives.
            drivings.wrappedValue = start
            _ = try await settle(index)

            try await Self.walk(
                scroller, from: start, to: target,
                horizontal: horizontal, driving: drivings, reported: times)
        }
    }

    /// Walks the offset to a card's middle over `settleTime`, whatever the
    /// distance, and gives up the moment the reader takes the carousel back.
    ///
    /// By HAND rather than by the platform's own animated scroll: that one
    /// takes as long as it takes, which is a different length of braking for
    /// every distance, and this one is the same movement every time. The
    /// position is worked out from the CLOCK rather than from a step count, so
    /// what the round trip to the scroller costs comes out of the number of
    /// steps and never out of the duration.
    private static nonisolated(nonsending) func walk(
        _ scroller: ControlState<ScrollView>,
        from start: Double,
        to target: Double,
        horizontal: Bool,
        driving: State<Double?>,
        reported: State<ContinuousClock.Instant?>
    ) async throws {
        let began = ContinuousClock.now
        let length = Double(settleTime) / 1000

        while true {
            let part = min(1, seconds(from: began, to: ContinuousClock.now) / length)

            // Eased out: most of the distance early and the last of it gently,
            // which is what a movement that is FINISHING looks like.
            let left = 1 - part
            let at = start + (target - start) * (1 - left * left * left)

            driving.wrappedValue = at

            try await scroller.scrollTo(
                x: horizontal ? at : 0,
                y: horizontal ? 0 : at,
                animated: false)

            // The reader took it back mid-walk.
            guard driving.wrappedValue != nil else { return }
            guard part < 1 else { break }

            try await Task.sleep(for: .milliseconds(settleFrame))
        }

        // The walk is over, and its LAST reports have not arrived yet: a
        // scroller answers a moment behind. Held open for the same quiet a
        // settle waits out, those echoes are still the carousel's own - let go
        // of at once they read as the READER moving the offset backwards, and
        // the carousel settles one card behind where it just landed. Measured
        // on Mac Catalyst, and it looked exactly like a carousel that cannot
        // make up its mind.
        driving.wrappedValue = target

        // And the next report is the start of a movement, not the middle of
        // this one: nothing to measure a speed against.
        reported.wrappedValue = nil

        try await Task.sleep(for: .milliseconds(settleQuiet))

        if let asked = driving.wrappedValue, abs(asked - target) <= settleTolerance {
            driving.wrappedValue = nil
        }
    }

    /// How far an offset travelling at this speed would go before it stopped -
    /// the distance of a walk that sheds the speed evenly over `settleTime`.
    ///
    /// A speed below `settleStill` is a carousel the reader parked rather than
    /// threw, and carries nothing. One above it but below `settleFloor` is
    /// carried at the floor, so a small flick still reaches the next card
    /// instead of falling back onto the one it left.
    private static func travel(at speed: Double) -> Double {
        guard abs(speed) > settleStill else { return 0 }

        let carried = abs(speed) < settleFloor ? (speed < 0 ? -settleFloor : settleFloor) : speed

        return carried * (Double(settleTime) / 1000) / 2
    }

    /// How fast the offset is travelling, in device units a second and signed.
    ///
    /// A speed is only meaningful between two reports of ONE movement. The
    /// first report of a touch has nothing to compare against, and a report a
    /// long time after the last one is the START of a movement rather than the
    /// middle of a fast one - both read as standing still. Two reports in the
    /// same instant are the other end of that scale: distance in no time is as
    /// fast as anything gets.
    private static func speed(
        of distance: Double,
        since last: ContinuousClock.Instant?,
        at now: ContinuousClock.Instant
    ) -> Double {
        guard let last else { return 0 }

        let elapsed = seconds(from: last, to: now)

        if elapsed >= settleGap { return 0 }
        if elapsed <= 0 { return distance == 0 ? 0 : (distance < 0 ? -.infinity : .infinity) }

        return distance / elapsed
    }

    /// The longest gap between two reports that still counts as one movement,
    /// in seconds. A platform reports a fling every frame, so anything this far
    /// apart is a new touch rather than a fast one.
    private static var settleGap: Double { 0.25 }

    /// The distance between two instants, in seconds.
    private static func seconds(
        from: ContinuousClock.Instant,
        to: ContinuousClock.Instant
    ) -> Double {
        let elapsed = to - from

        return Double(elapsed.components.seconds)
            + Double(elapsed.components.attoseconds) * 1e-18
    }

    /// Where the carousel is asked to be: the position an author assigned, and
    /// the size the layout settled on - both of which move the offset without
    /// the reader touching anything.
    private func watching(_ scroll: ScrollView, _ plan: Plan) -> Element {
        let offsets = _offset
        let drivings = _driving
        let times = _reportedAt
        let scroller = scroller
        let glides = glides
        let middle = current
        let horizontal = plan.horizontal
        let centres = _centred
        let recentre: EventHandler = {
            // The run is laid out at a new LENGTH every time the deck grows,
            // and a longer run moves no card: `origin` counts from the start
            // and knows nothing about the count. So the card in the middle is
            // put back only when the GEOMETRY moved - a first measurement, a
            // resize, a turn - and a deck that grew under a reader's finger is
            // left alone. Measured on Mac Catalyst: re-centring on the length
            // pulled a scroll in progress back onto the card it started from.
            // Never over a walk in flight: the carousel is moving the offset
            // itself, and a second movement would drag it back.
            guard plan.settled, drivings.wrappedValue == nil else { return }
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
                // A settle that moved the position is already walking the
                // offset there, and two movements at once are a fight.
                guard plan.settled, drivings.wrappedValue == nil else { return }

                let start = offsets.wrappedValue
                let target = plan.offset(of: plan.clamped(middle))
                guard abs(target - start) > Self.settleTolerance else { return }

                // The same walk a settle makes, so a button and a swipe move
                // the carousel the same way and take the same time.
                guard glides else {
                    try await scroller.scrollTo(
                        x: horizontal ? target : 0,
                        y: horizontal ? 0 : target,
                        animated: false)
                    return
                }

                drivings.wrappedValue = start

                try await Self.walk(
                    scroller, from: start, to: target,
                    horizontal: horizontal, driving: drivings, reported: times)
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

        /// Which card a movement ENDS on: the one nearest where the offset
        /// would come to rest, and never more than one card on from where the
        /// movement was when it was let go.
        ///
        /// The cap is what makes a hard flick feel like a carousel rather than
        /// like a list: whatever the speed, the reader asked for the next card.
        func landing(from offset: Double, travelling distance: Double) -> Int {
            // Past either end the scroller is springing back, and the card to
            // land on is the end one whatever the speed says.
            if offset <= 0 { return 0 }
            if offset >= self.offset(of: count - 1) { return clamped(count - 1) }

            let here = nearest(to: offset)
            let there = nearest(to: offset + distance)

            return clamped(min(max(there, here - 1), here + 1))
        }

        /// Which card an offset is nearest - the settle's whole arithmetic.
        func nearest(to offset: Double) -> Int {
            guard slot > 0 else { return 0 }

            return clamped(Int((offset / slot).rounded()))
        }

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
