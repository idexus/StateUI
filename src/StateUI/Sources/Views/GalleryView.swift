// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A RUN OF CARDS THE READER SWIPES THROUGH, and one word says which shape they
// stand in.
//
//     GalleryView(albums, id: \.title) { album in
//         AlbumFace(album)
//     }
//     .galleryStyle(.fan)
//     .position($shown)
//
// WHAT IT IS MADE OF. A `PlacedLayout` for the cards, a `ScrollReader` for the
// hand, and a `@State(describing: .none)` between them: the offset of an empty scroller lying
// over the cards is written into a value nothing describes for, and the
// arithmetic that places the cards reads it. So the run follows a finger, a
// trackpad and a wheel frame by frame with no view built, nothing compared and
// no message sent - and the only render is the one that crosses a card, which
// is what tells the rest of the page which card the reader is on.
//
// The three shapes are three closures over the same three numbers - which card
// this is, how many there are, and the room. Each answers where the card goes,
// how far it is turned, how big it looks and how opaque it is; a change of
// shape is those values changing, so the cards FLY from one arrangement to the
// next with nothing here saying a word about animation.

/// Which shape a `GalleryView` stands its cards in. This library's own.
///
/// One word per arrangement, and the cards travel between them: the shape is a
/// set of values like any other, so a gallery told to be a fan carries every
/// card from where it was to where the fan puts it.
public enum GalleryStyle: Sendable, Equatable {
    /// The cards stand on a wheel: the one in the middle faces the reader and
    /// the rest turn away, shrink and fade behind it.
    case `default`

    /// A hand of cards: the middle one stands tallest and its neighbours lean
    /// out and sink.
    case fan

    /// Side by side, the middle card largest - a strip to run along rather
    /// than a deck to look into.
    case row
}

/// One card at a time, swiped through - in a shape one word chooses.
/// This library's own.
///
///     @State private var shown = 0
///
///     GalleryView(albums, id: \.title) { album in
///         AlbumFace(album)
///     }
///     .galleryStyle(.default)
///     .position($shown)
///     .onItemTapped { open(albums[shown]) }
///
/// The initializer IS the card's face - one card per item, the item its
/// identity - and it says nothing about where the card goes or which way it
/// faces. That is the SHAPE's, and keeping the two apart is what lets one run
/// of cards wear three arrangements and travel between them.
///
/// **It needs a bounded size**, as a scroller does: a `.heightRequest`, or a
/// star row of a Grid. A gallery is a window onto a run of cards, and the cards
/// are placed in whatever room it is given - a narrow window shows the same
/// gallery smaller rather than three slivers of a large one.
///
/// **The reader's swipe SETTLES on a card**, and `.position($:)` is which one.
/// Assigning that binding moves the run, so a button, a tap and a swipe all say
/// the same thing.
///
/// **A tap opens the card in the MIDDLE.** A gallery is swiped to choose and
/// tapped to open, and the middle card is the choice - `.onItemTapped` is
/// handed it.
///
/// **Nothing is described while the run moves.** The offset rides a driven state,
/// which is read and written without the interface being described again, so
/// the whole run turns for the cost of the arithmetic. The one render is the
/// card CHANGING, which is what a caption under the gallery is written from.
public struct GalleryView<Items: RandomAccessCollection, Id: Hashable>: ContentView {
    // The state is declared FIRST, deliberately: a box is adopted by its PATH,
    // which is the stored property's own name at every level
    // (Core/Stateful.swift), and a card's face stored below may build composed
    // views carrying boxes of their own.

    /// Which card is in the middle, where no binding was lent.
    @State private var shown = 0

    /// The slot the SCROLLER last named, which is what tells a position the
    /// reader swiped to from one somebody assigned: only an assigned one has
    /// anything to move.
    @State private var reported = 0

    /// The shape the cards are IN, which is one render behind the shape asked
    /// for.
    ///
    /// A change of shape has to TRAVEL, and a render describes where a card is
    /// going before anything can be told that it changed - so the cards keep
    /// the shape they are in for the render that notices, and fly in the next
    /// one. Nothing, until the first change: the shape asked for is the shape
    /// a gallery opens in.
    @State private var wearing: GalleryStyle?

    /// Whether the cards are TRAVELLING to a new shape rather than following
    /// the scroller.
    @State private var flying = false

    /// How wide the room was when it last reported - what says a new layout has
    /// happened, which is when an offset refused before can finally land.
    @State private var measured = 0.0

    /// Whether the card in front is being held down.
    ///
    /// The press said back, and this library's own doing rather than the
    /// author's: what the reader taps is the SCROLLER, which lies over the
    /// cards and takes every touch, so a card cannot answer a press by itself.
    @State private var pressed = false

    /// The scroller the cards are turned by, for the gallery's own moves.
    @State private var scroller = ControlState<ScrollView>()

    /// How far the run has been scrolled, in device units. NOT state: it moves
    /// many times a second, and a view rebuilt for each of them is a view that
    /// lags. See Core/HostState.swift.
    @State(describing: .none) private var scrolled = 0.0

    /// Where every card stands - one placement each, in the order the cards
    /// are in. Written by the engine below on the display's own frames and
    /// worn there, so a hand turning the run costs no render at all.
    @State(describing: .none) private var placements = PlacedRun()

    /// How big the room the cards stand in is, as the platform reports it.
    /// Everything the arithmetic answers is scaled by it - see `fit(in:)`.
    @State(describing: .none) private var room = Rect(0, 0, 0, 0)

    /// The items and their card face, held BY REFERENCE - which is what stops
    /// the state walk here. See Core/Stateful.swift.
    private let source: Source

    /// Where the middle card is written, when an author lent a binding.
    private var pin: Binding<Int>?

    /// What runs when the middle card changes, beside any binding.
    private var moved: ValueEventHandler<Int>?

    /// What runs when the reader taps the run.
    private var tapped: ValueEventHandler<Items.Element>?

    /// Which shape the cards stand in.
    private var look = GalleryStyle.default

    /// How wide a card is, in device units.
    private var cardWidth = 176.0

    /// And how tall.
    private var cardHeight = 248.0

    /// Whether the reader may swipe at all.
    private var swipes = true

    /// The most cards one swipe may cross. Zero is as many as it carries.
    private var limit = 0

    /// What stands in when there are no items at all.
    private var empty: Element?

    /// What is drawn over a card to send it into the background, where the run
    /// darkens its far cards rather than fading them. See `shade(_:amount:)`.
    private var mask: Element?

    /// How far the shade goes, from 0 to 1.
    private var shades = 1.0

    /// How far the fade goes, where the author said. See `fade`.
    private var fades: Double?

    /// One card per item, the item its identity.
    ///
    ///     GalleryView(covers) { cover in
    ///         Image(cover)
    ///     }
    ///
    /// - Parameters:
    ///   - items: What the gallery shows, one card each.
    ///   - content: The card's face, run for every item.
    public init(
        _ items: Items,
        content: @escaping (Items.Element) -> Element
    ) where Items.Element: Hashable, Id == Items.Element {
        self.init(items, id: \.self, content: content)
    }

    /// The same, for items identified by the part `id` names - for items that
    /// are not `Hashable` whole or that repeat.
    ///
    ///     GalleryView(chapters, id: \.number) { chapter in
    ///         ChapterFace(chapter)
    ///     }
    ///
    /// - Parameters:
    ///   - items: What the gallery shows, one card each.
    ///   - id: Which part of an item is its identity - distinct across the
    ///     items, and stable while the item means the same card.
    ///   - content: The card's face, run for every item.
    public init(
        _ items: Items,
        id: KeyPath<Items.Element, Id>,
        content: @escaping (Items.Element) -> Element
    ) {
        source = Source(items: items, path: id, card: content)
    }

    /// Which shape the cards stand in. A wheel unless this says otherwise.
    /// This library's own.
    ///
    ///     GalleryView(albums) { … }.galleryStyle(.fan)
    ///
    /// The cards TRAVEL to the new arrangement: where a card goes, how far it
    /// is turned and how big it looks are values like any other, so changing
    /// the word carries the whole run across.
    ///
    /// - Parameter style: the arrangement.
    /// - Returns: the gallery, in that shape.
    public func galleryStyle(_ style: GalleryStyle) -> Self {
        var copy = self
        copy.look = style
        return copy
    }

    /// Which card is in the middle, counting from 0 - and where a swipe writes
    /// the one it settled on. This library's own, two-way.
    ///
    ///     @State private var shown = 0
    ///
    ///     GalleryView(albums) { … }.position($shown)
    ///     Label(albums[shown].title)
    ///
    /// Assigning it moves the run. A gallery nobody lends a binding to keeps
    /// the card itself and still settles on one.
    ///
    /// - Parameter binding: where the middle card is written and read.
    /// - Returns: the gallery, keeping its card there.
    public func position(_ binding: Binding<Int>) -> Self {
        var copy = self
        copy.pin = binding
        return copy
    }

    /// Another card came to the middle, and this is which one. This library's
    /// own.
    ///
    /// Beside `.position($:)` rather than instead of it: the binding is where
    /// the number lives, and this is for what has to HAPPEN when it moves. A
    /// card brought to the middle by an assignment is as arrived at as one
    /// swiped to.
    ///
    /// - Parameter handler: what to run, given the card's index.
    /// - Returns: the gallery, telling that handler.
    public func onPositionChanged(_ handler: @escaping ValueEventHandler<Int>) -> Self {
        var copy = self
        copy.moved = handler
        return copy
    }

    /// The reader tapped the run, and this is the item in the MIDDLE. This
    /// library's own.
    ///
    ///     GalleryView(groups, id: \.route) { … }
    ///         .position($shown)
    ///         .onItemTapped { group in open(group) }
    ///
    /// A gallery is swiped to choose and tapped to open, so the card the tap is
    /// about is the one the run has settled on - which is the card filling the
    /// middle of the view, whatever part of it the finger landed on.
    ///
    /// - Parameter handler: what to run, given the middle item.
    /// - Returns: the gallery, answering a tap.
    public func onItemTapped(_ handler: @escaping ValueEventHandler<Items.Element>) -> Self {
        var copy = self
        copy.tapped = handler
        return copy
    }

    /// How big a card is, in device units - and with it, THE SHAPE OF ONE.
    /// 176 by 248 unless this says otherwise. This library's own.
    ///
    /// THE RUN IS FITTED TO THE ROOM IT IS GIVEN, up as well as down, and by
    /// both sides at once: a card takes at most half the room's width and
    /// stands within its height, so a taller window draws taller cards and a
    /// narrow one draws the same gallery smaller. What this states is the
    /// PROPORTIONS that fitting keeps, and the size a card is drawn at in a
    /// room exactly the size for it.
    ///
    /// ONE SIZE IN EVERY SHAPE, and how big a card LOOKS is the shape's:
    /// sizing by the rectangle would put the run through a change of size as
    /// well as of place at every switch, which is two journeys where one will
    /// do.
    ///
    /// - Parameters:
    ///   - width: how wide a card is, against its height.
    ///   - height: how tall.
    /// - Returns: the gallery, with cards that shape.
    public func itemSize(width: Double, height: Double) -> Self {
        var copy = self
        copy.cardWidth = max(1, width)
        copy.cardHeight = max(1, height)
        return copy
    }

    /// Whether the reader may swipe at all. This library's own.
    ///
    /// A gallery that says no still moves when its position is assigned - it is
    /// the reader's hand that is stopped, not the gallery - and the cards
    /// travel to the card assigned rather than following a finger.
    ///
    /// - Parameter value: whether a finger, a trackpad or a wheel moves it.
    /// - Returns: the gallery, hearing the reader or not.
    public func isSwipeEnabled(_ value: Bool) -> Self {
        var copy = self
        copy.swipes = value
        return copy
    }

    /// The most cards one swipe may cross. Nothing is the default, and means as
    /// many as the throw carries. This library's own - the same limit
    /// `ScrollView.snapsAtMost` is.
    ///
    ///     GalleryView(steps) { … }.snapsAtMost(1)
    ///
    /// A hard swipe crosses several cards, which is right for a deck somebody
    /// is looking THROUGH and wrong for one they are stepping through. At `1`
    /// every swipe moves exactly one card, however hard it was thrown, and the
    /// card still arrives the way any other swipe brings one.
    ///
    /// - Parameter cards: how many cards a swipe may cross. Zero is no limit.
    /// - Returns: the gallery, holding a swipe to that many.
    public func snapsAtMost(_ cards: Int) -> Self {
        var copy = self
        copy.limit = max(0, cards)
        return copy
    }

    /// What the gallery shows while it has no items at all. This library's own.
    ///
    /// - Parameter view: what stands in for the cards.
    /// - Returns: the gallery, showing that instead of nothing.
    public func emptyView(_ view: Element) -> Self {
        var copy = self
        copy.empty = view
        return copy
    }

    /// What to draw over a card to send it into the background, and how far it
    /// goes. This library's own.
    ///
    ///     GalleryView(covers, id: \.name) { face($0) }
    ///         .shade(BoxView(Color("#000000")).cornerRadius(14))
    ///
    /// A run of cards puts its far cards behind the one in front, and there are
    /// two ways to say so. Fading is the one this does without: a card faded to
    /// a half shows whatever is BEHIND it, which in the wheel and the fan is
    /// the next card rather than the page. A shade darkens what is there, and
    /// the card in front wears none of it.
    ///
    /// The view is drawn over every card, so it is a SHAPE rather than a
    /// picture: give it the corners the card has, or its own square edges show
    /// at each of them. Told this, the gallery also drops its fade to a quarter,
    /// because a card that only darkens reads as lit differently rather than as
    /// further away - `fading(_:)` is how to say otherwise.
    ///
    /// - Parameters:
    ///   - view: what to draw over each card.
    ///   - amount: how dark the furthest card goes, from 0 (not at all) to 1
    ///     (as far as the shape says). The whole of it, unless said.
    /// - Returns: the gallery, darkening its far cards.
    public func shade(_ view: Element, amount: Double = 1) -> Self {
        var copy = self
        copy.mask = view
        copy.shades = Self.fraction(amount, "shade(_:amount:)")
        return copy
    }

    /// How far the cards away from the middle FADE, from 0 (not at all) to 1
    /// (as far as the shape says). This library's own.
    ///
    ///     GalleryView(covers, id: \.name) { face($0) }
    ///         .shade(BoxView(Color("#000000")).cornerRadius(14))
    ///         .fading(0)
    ///
    /// The whole of what the shape says, unless the gallery was also given a
    /// `shade(_:amount:)` - then a quarter of it, the shade carrying the rest.
    /// This is what says otherwise, either way: nought leaves a far card as
    /// opaque as the one in front, and one fades it as far as the shape goes
    /// whatever else it wears.
    ///
    /// - Parameter amount: how far a far card fades.
    /// - Returns: the gallery, fading that much.
    public func fading(_ amount: Double) -> Self {
        var copy = self
        copy.fades = Self.fraction(amount, "fading(_:)")
        return copy
    }

    /// A strength held to what a strength can be, saying so where it had to.
    ///
    /// HELD RATHER THAN REFUSED: a gallery given 1.4 is a gallery an author is
    /// still writing, and taking the page down over a constant would answer the
    /// wrong question. So the value carries on working at the nearest one that
    /// means something, and the complaint is what says which - once, and to
    /// four platforms of the five. See Core/Complaint.swift.
    ///
    /// - Parameters:
    ///   - amount: what the author wrote.
    ///   - modifier: which one they wrote it on, so the message names it.
    /// - Returns: the same number, between 0 and 1.
    private static func fraction(_ amount: Double, _ modifier: String) -> Double {
        guard amount.isFinite else {
            complain("GalleryView.\(modifier) was given a number that is not one. Using 1.")
            return 1
        }

        let held = min(max(amount, 0), 1)

        if held != amount {
            complain("""
                GalleryView.\(modifier) takes a strength from 0 to 1, and was \
                given \(amount). Using \(held).
                """)
        }

        return held
    }

    /// The cards, the shape they stand in, and the scroller that turns them.
    public var content: Element {
        let items = source.items
        let count = items.count

        if count == 0, let empty {
            return empty
        }

        // BUILT OUT OF LOCALS rather than `self`: this view holds a class, and
        // a handler closure that captures one can leave this library's
        // executor.
        let reports = _reported
        let showns = _shown
        let worn = _wearing
        let flies = _flying
        let measures = _measured
        let mover = scroller
        let offset = _scrolled
        let pin = pin
        let moved = moved
        let tapped = tapped
        let look = look
        let swipes = swipes
        let step = reach
        let position = min(max(pin?.wrappedValue ?? shown, 0), count - 1)
        let middle = items.index(items.startIndex, offsetBy: position)
        let path = source.path
        let make = source.card
        let down = pressed
        let presses = _pressed
        let chosen = items[middle][keyPath: path]

        // THE SHAPE AND THE LAW ARE READ HERE, in the body, and handed to the
        // arithmetic below rather than looked up inside it. A read an ENGINE
        // makes is recorded NOWHERE - it runs on the host's own frames,
        // outside any render - so a state only the engine looked at would move
        // with nothing built again, no engine armed, and the cards left
        // standing in the shape they were last placed in.
        let shape = wearing ?? look
        let travels = flying
        let drawn = { (room: Rect) in self.front(in: room, shape: shape) }

        // A VIEW OF ITS OWN FOR THE PLACEMENT, and it has to be one: a card's
        // turn, fade and size are written by the DRIVEN STATE, on the host's own
        // frames, so a press written on the same node is snapped away by the
        // next of them. The wrapper is what the placement is written on; the
        // face inside it is left free, and the press there is an ordinary
        // property that travels.
        var run = PlacedLayout(items, id: source.path) { item in
            Grid {
                ModifiedContent(node: make(item).body)
                    .scale(down && item[keyPath: path] == chosen ? Self.dip : 1)
                    .motion(Self.pressing)
            }
        }

        // THE SHADE SITS BESIDE THE PRESS RATHER THAN OVER IT, and it costs
        // nothing here: the only card that dips is the one in front, and the
        // card in front is the one wearing no shade at all.
        if let mask {
            run = run.shade(mask)
        }

        let cards = run
            .placement($placements)
            .frame($room)
            // THE ARITHMETIC RUNS ON THE HOST'S OWN FRAMES, and `.engine(following:)`
            // says which values moving are a reason to run it again: the hand
            // that turns the run, and the room it is all scaled by.
            .engine(following: $scrolled, $room) { _ in
                placements = PlacedRun(
                    (0..<count).map { place($0, count, room, shape) },
                    // A PLACEMENT WORKED OUT FROM SOMETHING THE READER IS
                    // MOVING DOES NOT TRAVEL: the arithmetic is re-answered
                    // every frame, and a card a fifth of a second behind the
                    // hand is a card that lags. A change of SHAPE is the other
                    // case, and the only one where these do travel.
                    motion: travels ? .inherited : .none)
            }

        // WHERE THE RUN IS ASKED TO BE, and the shape it is asked to stand in.
        // Both are values somebody assigned, so both are WATCHED rather than
        // read: a position the scroller REPORTED is where the run already is,
        // and moving to it would report again.
        func watching(_ view: ModifiedContent) -> ModifiedContent {
            view
                .onChanged(position) {
                    guard position != reports.wrappedValue else { return }

                    reports.wrappedValue = position

                    if swipes {
                        try await mover.scrollTo(x: Double(position) * step, y: 0)
                    } else {
                        // NOTHING TO SCROLL, so the value is written and the
                        // cards travel to what the arithmetic now says.
                        flies.wrappedValue = true
                        offset.wrappedValue = Double(position) * step

                        try await Task.sleep(for: .milliseconds(Self.crossing))

                        flies.wrappedValue = false
                    }
                }
                .onChanged(position) {
                    if let moved { try await moved(position) }
                }
                .onChanged(look) {
                    // THE SHAPE IS WORN A RENDER LATE, so there is a render in
                    // which the cards are told they may travel BEFORE they are
                    // told where to. Described in the same render, they would
                    // already be there.
                    flies.wrappedValue = true
                    worn.wrappedValue = look

                    try await Task.sleep(for: .milliseconds(Self.crossing))

                    flies.wrappedValue = false
                }
        }

        guard swipes else {
            return watching(ModifiedContent(node: cards.body))
        }

        var reader = ScrollReader(across: Double(count - 1) * step) { cards }
            .scrollX($scrolled)
            // ONE CARD PER `reach`, so the platform's own snapping settles the
            // run on the card it is nearest.
            .snapInterval(step)
            // A RUN OF CARDS WANTS LESS THROW THAN A LIST DOES - see `carry`.
            .momentum(Self.carry)
            .snapItem(
                Binding(
                    get: { reports.wrappedValue },
                    set: { slot in
                        let card = min(max(slot, 0), count - 1)

                        reports.wrappedValue = card

                        if let pin {
                            if pin.wrappedValue != card { pin.wrappedValue = card }
                        } else if showns.wrappedValue != card {
                            showns.wrappedValue = card
                        }
                    }))
            .assign(mover)

        if limit > 0 {
            reader = reader.snapsAtMost(limit)
        }

        if let tapped {
            // WHERE THE CARD IN FRONT STANDS IN THE ROOM, taken through its
            // own shape's transform - a wheel's middle card is drawn larger
            // than its rectangle, a row's smaller. The reader keeps the box
            // there as the run moves, so what answers a tap is the card the
            // reader is looking at and nothing else: a tap on the empty run
            // beside it is not a tap on a card.
            reader = reader.onTapped(within: drawn) {
                // THE PRESS RUNS FIRST AND THE RETURN RIDES THE ACTION - the
                // card's own rule, and for the card's own reason: tapping a
                // card usually builds a page, and a page built on this thread
                // eats every frame beside it. The tree says the card is back
                // at its own size the moment the press is let go, so it draws
                // right whether the walk was ever seen or not.
                presses.wrappedValue = true

                try await Task.sleep(for: .milliseconds(Self.held))

                presses.wrappedValue = false

                try await tapped(items[middle])
            }
        }

        return watching(
            reader
                // THE RUN IS PUT WHERE THE POSITION SAYS, whenever a layout
                // has happened and it is not there.
                //
                // WHICH IS THE FIRST SHOWING AND EVERY ONE AFTER IT: a
                // scroller cannot be moved before its content is laid out -
                // asked earlier it clamps to the length it has so far - so
                // this asks again until the card arrives, and a scroller
                // built AFRESH, by a resize or by the reader's hand being
                // given back, is a scroller standing at nothing with the same
                // answer.
                .onFrameChanged { frame in
                    let sendTo = Double(position) * step
                    let astray = abs(offset.wrappedValue - sendTo) > 1

                    guard astray || frame.width != measures.wrappedValue else { return }

                    measures.wrappedValue = frame.width

                    var asks = 0

                    while abs(offset.wrappedValue - sendTo) > 1, asks < 10 {
                        try await mover.scrollTo(x: sendTo, y: 0, animated: false)
                        try await Task.sleep(for: .milliseconds(100))
                        asks += 1
                    }
                })
    }

    /// How long one flight between two shapes lasts, in milliseconds - what the
    /// cards are let travel for before they go back to following the hand.
    private static var crossing: Int { 500 }

    /// How small the card in front is drawn while it is held down.
    private static var dip: Double { 0.96 }

    /// How long the card is held down before the tap's own work begins, in
    /// milliseconds - long enough for the press to be seen at all.
    private static var held: Int { 60 }

    /// How the press travels, down and back.
    ///
    /// Short both ways: a press is an answer to a finger, and an answer that
    /// takes as long as a page does is not felt as one.
    private static var pressing: Motion { .eased(50, .cubicOut) }

    /// How far a far card FADES, from 0 to 1, unless the author said.
    ///
    /// All of it where the gallery was given no shade view, and a quarter where
    /// it was: a card that only darkens reads as lit differently rather than as
    /// further away, and the little fade left over is what puts it behind. The
    /// rest is the shade's, which darkens the card instead of showing the card
    /// behind it. See `fading(_:)` and `shade(_:amount:)`.
    private var fade: Double { fades ?? (mask == nil ? 1 : 0.25) }

    /// How far the hand travels to turn the run by one card, in device units.
    ///
    /// THIS IS THE SENSITIVITY, and it is the only thing that is. The run's
    /// content is the room plus one of these per card past the first, so what
    /// a device sends - a constant, whatever it is - buys a card in proportion
    /// to this number and nothing else. Three fifths of a card's width: far
    /// enough that the coarsest thing a device can say is a part of a card
    /// rather than more than one, near enough that a deck is quick to cross.
    private var reach: Double { cardWidth * 0.6 }

    /// How much of the platform's own throw a release keeps.
    ///
    /// Half. A touch platform throws a scroller far enough to cross a
    /// long list, which over a run of CARDS is most of the deck for one flick
    /// - past whatever the reader was aiming at, and a swipe back to find it.
    /// Scaled rather than replaced, so a hard throw still carries further than
    /// a gentle one. MAUI has no such property; this is `ScrollView.momentum`.
    private static var carry: Double { 0.5 }

    /// How far the run is turned, in CARDS - a whole number at rest and
    /// whatever the scroller says while it is moving.
    ///
    /// A READING FROM OUTSIDE IS NOT A NUMBER UNTIL IT IS CHECKED: a platform
    /// that reports through a transform can answer with no number at all.
    private var at: Double {
        let turned = scrolled / reach

        guard turned.isFinite else { return 0 }

        return min(max(turned, 0), Double(max(source.items.count - 1, 0)))
    }

    /// How big the cards are DRAWN in THIS room, as a multiple of the size they
    /// were told - which is the whole of how a gallery fits itself, what every
    /// distance below scales with, and what each shape multiplies its own scale
    /// by. The rectangle stays the size the author stated, so what is inside a
    /// card comes down with it - see `card`.
    ///
    /// BOTH AXES, always: a card takes at most half the room's width and stands
    /// within its height, and the smaller of the two answers. So a window grown
    /// taller draws taller cards, a narrow one draws the same gallery smaller,
    /// and a phone on its side - plenty of width, almost no height - is
    /// answered by the height.
    ///
    /// It grows only so far: a card is a card, and one blown up to fill a
    /// desk is a picture. Past `largest` the room is simply room, and the run
    /// stands in the MIDDLE of it - which it does at every size, the
    /// arithmetic being written from the middle out.
    private func fit(in room: Rect) -> Double {
        min(
            Self.largest,
            max(room.width, 1) * 0.5 / cardWidth,
            max(room.height, 1) / (cardHeight * Self.headroom))
    }

    /// How much taller than a card the room has to be for it to stand at its
    /// full size - the room the fan's lift and a turned card's corners need.
    private static var headroom: Double { 1.16 }

    /// How much bigger than the size it was told a card may be drawn. About a
    /// third again: enough that a desktop window is used and not so much that
    /// one card becomes the page. An author who wants more says a bigger
    /// `itemSize`.
    private static var largest: Double { 1.375 }

    /// Where one card goes and how it is turned - the whole of the layout.
    ///
    /// THE ABSENCE OF A SHADE IS A NUMBER, because the host cannot see this
    /// side's views: it is handed a run of doubles and the placed control, and
    /// `unshaded` is what tells it there is no shade view under one. A gallery
    /// that HAS one answers nought for the card in front, and nought is a
    /// shade like any other.
    private func place(
        _ index: Int,
        _ count: Int,
        _ room: Rect,
        _ shape: GalleryStyle
    ) -> Placement {
        var placement = placed(Double(index) - at, count, room, shape)

        placement.shade = mask == nil
            ? PackedPlacement.unshaded
            : min(max(placement.shade, 0), 1)

        return placement
    }

    /// Where the card in front of the reader is DRAWN, in the room.
    ///
    /// The placement of a card the run is exactly ON - which is what the
    /// middle of the room holds whatever the offset is - taken through its own
    /// shape's transform, so the answer is the card as the reader sees it
    /// rather than the rectangle it was laid out in.
    private func front(in room: Rect, shape: GalleryStyle) -> Rect {
        let placement = placed(0, source.items.count, room, shape)
        let box = placement.bounds
        let transform = placement.transform
        let wide = box.width * transform.width
        let tall = box.height * transform.height

        return Rect(
            box.x + (box.width - wide) / 2 + transform.x,
            box.y + (box.height - tall) / 2 + transform.y,
            wide,
            tall)
    }

    /// The same, for a card however far it stands from the one in front.
    private func placed(
        _ step: Double,
        _ count: Int,
        _ room: Rect,
        _ shape: GalleryStyle
    ) -> Placement {
        let fit = fit(in: room)

        switch shape {
        case .fan:
            return fan(step, room, fit)

        case .row:
            return row(step, count, room, fit)

        case .default:
            return wheel(step, room, fit)
        }
    }

    /// A WHEEL: the cards stand on it, the one in the middle facing the reader
    /// and the rest turning away, shrinking and fading behind it.
    private func wheel(_ step: Double, _ room: Rect, _ fit: Double) -> Placement {
        let near = max(-2.4, min(2.4, step))
        let away = min(abs(near), 1.55) / 1.55

        // TURNED, SIZED AND TIPPED IN ONE PLACE. `turn` is a turn about the
        // card's vertical axis drawn FLAT, which is the same picture on every
        // platform - `.rotationY` is the other reading, and every platform
        // projects that one through a camera of its own.
        let dim = min(max(abs(near) - 0.35, 0) / 3, 0.62)

        return Placement(
            card(room, up: 0, across: near * cardWidth * 0.52 * fit),
            transform: .turn(away * 64)
                .scale((1.1 - min(abs(near), 1.6) * 0.2) * fit)
                .rotate(near * 3),
            opacity: 1 - dim * fade,
            shade: dim * shades,
            zIndex: order(step))
    }

    /// A FAN: the card in the middle stands tallest and the ones beside it lean
    /// away and sink.
    private func fan(_ step: Double, _ room: Rect, _ fit: Double) -> Placement {
        let near = max(-2.6, min(2.6, step))

        let dim = min(max(abs(near) - 0.35, 0) / 3.4, 0.5)

        return Placement(
            card(
                room,
                up: abs(near) * cardHeight * 0.065 * fit,
                across: near * cardWidth * 0.4 * fit),
            transform: .rotate(near * 6).scale((0.9 - min(abs(near), 2) * 0.1) * fit),
            opacity: 1 - dim * fade,
            shade: dim * shades,
            zIndex: order(step))
    }

    /// A ROW, side by side - and no wider than the room, however many cards
    /// there are.
    private func row(_ step: Double, _ count: Int, _ room: Rect, _ fit: Double) -> Placement {
        let across = min(cardWidth * 0.64 * fit, room.width / Double(max(count, 1)))

        return Placement(
            card(room, up: 0, across: step * across),
            transform: .scale((0.58 + 0.16 * max(0, 1 - abs(step))) * fit),
            zIndex: order(step))
    }

    /// Which cards are drawn over which: the middle one nearest the reader, and
    /// the rest behind it in the order they stand away from it.
    private func order(_ step: Double) -> Int {
        1000 - Int(min(abs(step), 99) * 100)
    }

    /// A card's rectangle: THE SIZE IT WAS TOLD, whatever room the run is in,
    /// in the middle of that room and then moved by the arithmetic above.
    ///
    /// The room's own answer - `fit` - is a SCALE and not a rectangle, which is
    /// what carries a card's CONTENT down with it: a caption is laid out in the
    /// width the author wrote it for and drawn smaller, where a shrinking
    /// rectangle would keep the words their own size and cut them off. So the
    /// card is one size everywhere, and how big it looks is the room's and the
    /// shape's together.
    private func card(_ room: Rect, up: Double, across: Double) -> Rect {
        Rect(
            room.width / 2 + across - cardWidth / 2,
            room.height / 2 + up - cardHeight / 2,
            cardWidth,
            cardHeight)
    }

    /// The items and their card face, behind a class - which is what stops the
    /// Mirror walk that adopts state boxes from recursing through them.
    private final class Source {
        /// What the gallery shows.
        let items: Items

        /// Which part of an item is its identity.
        let path: KeyPath<Items.Element, Id>

        /// The card's face.
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
