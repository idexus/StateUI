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
// hand, and a `@Channel` between them: the offset of an empty scroller lying
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
/// **Nothing is described while the run moves.** The offset rides a channel,
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

    /// The scroller the cards are turned by, for the gallery's own moves.
    @State private var scroller = ControlState<ScrollView>()

    /// How far the run has been scrolled, in device units. NOT state: it moves
    /// many times a second, and a view rebuilt for each of them is a view that
    /// lags. See Core/Channel.swift.
    @Channel private var scrolled = 0.0

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

        let cards = PlacedLayout(items, id: source.path, following: $scrolled, at: place) { item in
            source.card(item)
        }
        // A PLACEMENT WORKED OUT FROM SOMETHING THE READER IS MOVING DOES NOT
        // TRAVEL: the arithmetic is re-answered on every report, and a card a
        // fifth of a second behind the hand is a card that lags. A change of
        // SHAPE is the other case, and the only one where these do travel.
        .motion(flying ? .inherited : .none)

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
            reader = reader.onTapped { try await tapped(items[middle]) }
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

    /// How far the hand travels to turn the run by one card, in device units.
    /// Half a card: far enough that a card is a deliberate movement, near
    /// enough that a deck is quick to cross.
    private var reach: Double { cardWidth / 2 }

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

    /// How big the cards are in THIS room, as a multiple of the size they were
    /// told - which is the whole of how a gallery fits itself, and what every
    /// distance below scales with.
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
    private func place(_ index: Int, _ count: Int, _ room: Rect) -> Placement {
        let step = Double(index) - at
        let fit = fit(in: room)

        switch wearing ?? look {
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
        return Placement(
            card(room, up: 0, across: near * cardWidth * 0.52 * fit, fit: fit),
            transform: .turn(away * 64)
                .scale(1.1 - min(abs(near), 1.6) * 0.2)
                .rotate(near * 3),
            opacity: 1 - min(max(abs(near) - 0.35, 0) / 3, 0.62),
            zIndex: order(step))
    }

    /// A FAN: the card in the middle stands tallest and the ones beside it lean
    /// away and sink.
    private func fan(_ step: Double, _ room: Rect, _ fit: Double) -> Placement {
        let near = max(-2.6, min(2.6, step))

        return Placement(
            card(
                room,
                up: abs(near) * cardHeight * 0.065 * fit,
                across: near * cardWidth * 0.4 * fit,
                fit: fit),
            transform: .rotate(near * 6).scale(0.9 - min(abs(near), 2) * 0.1),
            opacity: 1 - min(max(abs(near) - 0.35, 0) / 3.4, 0.5),
            zIndex: order(step))
    }

    /// A ROW, side by side - and no wider than the room, however many cards
    /// there are.
    private func row(_ step: Double, _ count: Int, _ room: Rect, _ fit: Double) -> Placement {
        let across = min(cardWidth * 0.64 * fit, room.width / Double(max(count, 1)))

        return Placement(
            card(room, up: 0, across: step * across, fit: fit),
            transform: .scale(0.58 + 0.16 * max(0, 1 - abs(step))),
            zIndex: order(step))
    }

    /// Which cards are drawn over which: the middle one nearest the reader, and
    /// the rest behind it in the order they stand away from it.
    private func order(_ step: Double) -> Int {
        1000 - Int(min(abs(step), 99) * 100)
    }

    /// A card's rectangle: the same size in every shape, in the middle of the
    /// room and then moved by the arithmetic above.
    private func card(_ room: Rect, up: Double, across: Double, fit: Double) -> Rect {
        Rect(
            room.width / 2 + across - cardWidth * fit / 2,
            room.height / 2 + up - cardHeight * fit / 2,
            cardWidth * fit,
            cardHeight * fit)
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
