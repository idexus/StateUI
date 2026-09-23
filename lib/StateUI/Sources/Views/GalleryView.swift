// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A run of cards the user swipes through, in a shape one word chooses: a
// PlacedLayout for the cards, a ScrollReader for the hand, and a state between.
// Design: docs/design/views/measured-layouts.md#gallery-view

/// One card at a time, swiped through, in a shape one word chooses.
///
///     @State private var shown = 0
///
///     GalleryView(albums, id: \.title) { album in
///         AlbumFace(album)
///     }
///     .arrangement(.default)
///     .position($shown)
///     .onItemTapped { open(albums[shown]) }
///
/// The initializer is the card's face, one card per item; where a card goes
/// and which way it faces is the arrangement's. Give the gallery a bounded
/// size, as a scroller needs - a `.height`, or a star row of a Grid - and the
/// cards are fitted to it.
///
/// A swipe settles on a card, and `.position($:)` says which; assigning it
/// moves the run. A tap opens the middle card, handed to `.onItemTapped`. No
/// view is rebuilt while the run moves: the one render is the card changing.
public struct GalleryView<Items: RandomAccessCollection, Id: Hashable>: ContentView {
    // State first: boxes are adopted by path, and the card faces stored below
    // may carry boxes of their own.
    // Design: docs/design/views/composition.md#state-declared-first

    /// Which card is in the middle, where no binding was lent.
    @State private var shown = 0

    /// The card the run last named as it passed: only a position somebody
    /// assigned has anything to move.
    @State private var reported = 0

    /// The shape the cards are in, one render behind the shape asked for, so a
    /// change of shape animates; nil until the first change.
    @State private var wearing: GalleryArrangement?

    /// Whether the cards are animating to a new shape rather than following
    /// the scroller.
    @State private var flying = false

    /// How wide the room was when it last reported - what says a new layout has
    /// happened, which is when an offset refused before can finally land.
    @State private var measured = 0.0

    /// Which card is held down, by its identity: the scroller over the cards
    /// takes every touch, so the gallery shows the press itself.
    @State private var dipping: Id?

    /// Whether a pointer drag has to move the run: a finger drags a scroller
    /// itself, a mouse does not.
    @Environment private var device: DeviceInfo

    /// Where the run is scrolled to, carried both ways and never read in a
    /// body; `$scrolled.journey.value` is where the run is.
    @State private var scrolled = Point.zero

    /// Where the run stood when a pointer drag began, which every report of
    /// the drag is measured from.
    @State private var dragged = 0.0

    /// Every card's placement, written by the engine on the host's frames.
    @State private var placements = PlacedRun()

    /// The room the cards stand in, as the platform reports it.
    @State private var room = Rect(0, 0, 0, 0)

    /// The items and their card face, behind a class so the state walk stops.
    private let source: Source

    /// Where the middle card is written, when an author lent a binding.
    private var pin: Binding<Int>?

    /// What runs when the middle card changes, beside any binding.
    private var moved: ValueEventHandler<Int>?

    /// What runs when the user taps the run.
    private var tapped: ValueEventHandler<Items.Element>?

    /// Which shape the cards stand in.
    private var look = GalleryArrangement.default

    /// How wide a card is, in device units.
    private var cardWidth = 176.0

    /// And how tall.
    private var cardHeight = 248.0

    /// Whether the user may swipe at all.
    private var swipes = true

    /// What stands in when there are no items at all.
    private var empty: (any View)?

    /// What is drawn over a far card to darken it. See `shade(_:amount:)`.
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

    /// Which shape the cards stand in - a wheel unless said. Changing it
    /// animates every card to the new shape.
    ///
    ///     GalleryView(albums) { … }.arrangement(.fan)
    ///
    /// - Parameter style: the arrangement.
    /// - Returns: the gallery, in that shape.
    public func arrangement(_ style: GalleryArrangement) -> Self {
        var copy = self
        copy.look = style
        return copy
    }

    /// Which card is in the middle, counting from 0, two-way: a swipe writes
    /// the card it settled on.
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

    /// Runs when another card comes to the middle, swiped or assigned, with
    /// its index.
    ///
    /// - Parameter handler: what to run, given the card's index.
    /// - Returns: the gallery, telling that handler.
    public func onPositionChanged(_ handler: @escaping ValueEventHandler<Int>) -> Self {
        var copy = self
        copy.moved = handler
        return copy
    }

    /// Runs when the user taps the run, with the item in the middle.
    ///
    ///     GalleryView(groups, id: \.route) { … }
    ///         .position($shown)
    ///         .onItemTapped { group in open(group) }
    ///
    /// The tap is about the card the run has settled on, wherever the finger
    /// landed.
    ///
    /// - Parameter handler: what to run, given the middle item.
    /// - Returns: the gallery, answering a tap.
    public func onItemTapped(_ handler: @escaping ValueEventHandler<Items.Element>) -> Self {
        var copy = self
        copy.tapped = handler
        return copy
    }

    /// How big a card is, in device units - 176 by 248 unless said.
    ///
    /// The run is fitted to its room, up as well as down: a card takes at most
    /// half the room's width and stands within its height. This states the
    /// proportions the fitting keeps, and the size a card is drawn at in a
    /// room exactly its size.
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

    /// Whether the user may swipe at all. A gallery that says no still moves
    /// when its position is assigned.
    ///
    /// - Parameter value: whether a finger, a trackpad or a wheel moves it.
    /// - Returns: the gallery, hearing the user or not.
    public func isSwipeEnabled(_ value: Bool) -> Self {
        var copy = self
        copy.swipes = value
        return copy
    }

    /// What the gallery shows while it has no items at all.
    ///
    /// - Parameter view: what stands in for the cards.
    /// - Returns: the gallery, showing that instead of nothing.
    public func emptyView(_ view: any View) -> Self {
        var copy = self
        copy.empty = view
        return copy
    }

    /// What to draw over a card to send it into the background, and how far.
    ///
    ///     GalleryView(covers, id: \.name) { face($0) }
    ///         .shade(ColorBox(Color("#000000")).cornerRadius(14))
    ///
    /// A shade darkens a far card without showing the card behind it, as
    /// fading would; the card in front wears none of it. Give the view the
    /// corners the card has. With a shade the fade drops to a quarter, unless
    /// `fading(_:)` says otherwise.
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

    /// How far the cards away from the middle fade, from 0 (not at all) to 1
    /// (as far as the shape says): all of it unless a `shade(_:amount:)` is
    /// given, and then a quarter.
    ///
    ///     GalleryView(covers, id: \.name) { face($0) }
    ///         .shade(ColorBox(Color("#000000")).cornerRadius(14))
    ///         .fading(0)
    ///
    /// - Parameter amount: how far a far card fades.
    /// - Returns: the gallery, fading that much.
    public func fading(_ amount: Double) -> Self {
        var copy = self
        copy.fades = Self.fraction(amount, "fading(_:)")
        return copy
    }

    /// A strength held between 0 and 1, saying so where it had to be: held
    /// rather than refused, so a gallery still being written keeps working.
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
    public var content: any View {
        let items = source.items
        let count = items.count

        if count == 0, let empty {
            return empty
        }

        // Locals rather than `self`, which holds a class.
        // Design: docs/design/views/composition.md#handlers-capture-locals
        let reports = _reported
        let showns = _shown
        let worn = _wearing
        let flies = _flying
        let measures = _measured
        let offset = _scrolled
        let drags = _dragged
        let pin = pin
        let moved = moved
        let tapped = tapped
        let look = look
        let swipes = swipes
        let step = reach
        let path = source.path
        let make = source.card
        let dips = _dipping

        // The asked position as a closure: read here, it would make this body a
        // reader, and every card crossed would rebuild the deck.
        // Design: docs/design/views/composition.md#a-watcher-is-a-view-of-its-own
        let asked = { min(max(pin?.wrappedValue ?? showns.wrappedValue, 0), count - 1) }

        // The shape and the motion are read here: a read an engine makes is
        // recorded nowhere, so a change read only there would move nothing.
        let shape = wearing ?? look
        let travels = flying
        let drawn = { (room: Rect) in self.front(in: room, shape: shape) }

        // The middle card, written only where it changed.
        let name = { (slot: Int) in
            let card = min(max(slot, 0), count - 1)

            guard card != reports.wrappedValue else { return }

            reports.wrappedValue = card

            if let pin {
                if pin.wrappedValue != card { pin.wrappedValue = card }
            } else if showns.wrappedValue != card {
                showns.wrappedValue = card
            }
        }

        // The face in a wrapper of its own, so the press on it is not overwritten
        // by the placement written on the wrapper every frame.
        var run = PlacedLayout(items, id: source.path) { item in
            Grid {
                ModifiedContent(node: make(item).body)
                    // Which card is pressed, never which is in front.
                    .scale(dips.wrappedValue == item[keyPath: path] ? Self.dip : 1)
                    .motion(Self.pressing)
            }
        }

        // The shade sits beside the press: the card that dips wears none.
        if let mask {
            run = run.shade(mask)
        }

        let cards = run
            .placement($placements)
            .frame($room)
            // The arithmetic runs again whenever the hand or the room moves.
            .engine(following: $scrolled, $room) { _ in
                placements = PlacedRun(
                    (0..<count).map { place($0, count, room, shape) },
                    // Following the hand, placements arrive; a shape change animates.
                    motion: travels ? .inherited : .none)

                // The middle card is named as the run passes halfway: one render
                // per card crossed, none per frame.
                if swipes {
                    name(Int((offset.projectedValue.journey.value.x / step).rounded()))
                }
            }

        // The watchers, a view of their own beside the deck, so reading the
        // asked position rebuilds none of the cards.
        let turning = Turning(
            at: asked,
            look: look,
            turned: { position in
                // A reported position is where the run already is: it moves
                // nothing, but the handler still hears it.
                guard position != reports.wrappedValue else {
                    if let moved { try await moved(position) }
                    return
                }

                reports.wrappedValue = position

                if swipes {
                    offset.wrappedValue = Point(Double(position) * step, 0)
                } else {
                    // Nothing to scroll: the cards animate to the new place.
                    flies.wrappedValue = true
                    offset.projectedValue.journey.snap(to: Point(Double(position) * step, 0))

                    try await Task.sleep(for: .milliseconds(Self.crossing))

                    flies.wrappedValue = false
                }

                if let moved { try await moved(position) }
            },
            wore: {
                // The shape is worn a render late, so the cards are told they
                // may animate before they are told where to.
                flies.wrappedValue = true
                worn.wrappedValue = look

                try await Task.sleep(for: .milliseconds(Self.crossing))

                flies.wrappedValue = false
            })

        guard swipes else {
            return Grid {
                ModifiedContent(node: cards.body)
                turning
            }
        }

        var reader = ScrollReader(across: Double(count - 1) * step) { cards }
            .scrollOffset($scrolled)
            // The run comes to rest on the nearest card, by a write.
            .onScrollStopped {
                let stood = offset.projectedValue.journey.value.x
                let rest = Double(min(max(Int((stood / step).rounded()), 0), count - 1)) * step

                if abs(stood - rest) > Self.settled {
                    offset.wrappedValue = Point(rest, 0)
                }
            }

        // On a desktop a pointer drag turns the run: a scroller takes no drag
        // from a mouse, and a finger drags the scroller itself.
        if device.formFactor == .desktop {
            reader = reader.onPanUpdated { pan in
                switch pan.phase {
                case .started:
                    drags.wrappedValue = offset.projectedValue.journey.value.x

                case .running:
                    // The offset is written, not the scroller: the drag is
                    // measured inside the content the scroller would move.
                    offset.projectedValue.journey.snap(to: Point(drags.wrappedValue - pan.totalX, 0))

                case .completed, .canceled:
                    let stood = offset.projectedValue.journey.value.x
                    let card = min(max(Int((stood / step).rounded()), 0), count - 1)

                    // Snap the scroller to where the run is, then animate on.
                    offset.projectedValue.journey.snap(to: Point(stood, 0))
                    offset.wrappedValue = Point(Double(card) * step, 0)
                }
            }
        }

        if let tapped {
            // The tap is answered on the card in front, as its shape draws it.
            reader = reader.onTapped(within: drawn) {
                // The press shows, and the card is back at its size, before the
                // tap's own work, which usually builds a page.
                let middle = items.index(items.startIndex, offsetBy: asked())

                dips.wrappedValue = items[middle][keyPath: path]

                try await Task.sleep(for: .milliseconds(Self.held))

                dips.wrappedValue = nil

                try await tapped(items[middle])
            }
        }

        return Grid {
            reader
                // After each layout the run is put where the position says,
                // asking again until it lands: an unlaid scroller clamps.
                .onFrameChanged { frame in
                    let sendTo = Double(asked()) * step
                    let astray = abs(offset.projectedValue.journey.value.x - sendTo) > 1

                    guard astray || frame.width != measures.wrappedValue else { return }

                    measures.wrappedValue = frame.width

                    var asks = 0

                    while abs(offset.projectedValue.journey.value.x - sendTo) > 1, asks < 10 {
                        offset.projectedValue.journey.snap(to: Point(sendTo, 0))
                        try await Task.sleep(for: .milliseconds(100))
                        asks += 1
                    }
                }

            turning
        }
    }

    /// How long one crossing between two shapes lasts, in milliseconds - what the
    /// cards are let travel for before they go back to following the hand.
    private static var crossing: Int { 500 }

    /// How small the card in front is drawn while it is held down.
    private static var dip: Double { 0.96 }

    /// How long the card is held down before the tap's own work begins, in
    /// milliseconds - long enough for the press to be seen at all.
    private static var held: Int { 60 }

    /// How the press animates, down and back: short, as an answer to a finger.
    private static var pressing: Motion { .eased(50, .cubicOut) }

    /// How far a far card fades unless said: all of it, or a quarter where a
    /// shade does the rest.
    private var fade: Double { fades ?? (mask == nil ? 1 : 0.25) }

    /// How far the hand travels to turn the run by one card - the sensitivity:
    /// three fifths of a card's width.
    private var reach: Double { cardWidth * 0.6 }

    /// How near a card the run has to stand to count as resting on it, in
    /// device units - closer than this is not worth a movement.
    private static var settled: Double { 0.5 }

    /// How far the run is turned, in cards; a reading that is not a finite
    /// number counts as none.
    private var at: Double {
        let turned = $scrolled.journey.value.x / reach

        guard turned.isFinite else { return 0 }

        return min(max(turned, 0), Double(max(source.items.count - 1, 0)))
    }

    /// How big the cards are drawn in this room, as a multiple of their stated
    /// size: the smaller of half the room's width and its height, up to
    /// `largest`.
    /// Design: docs/design/views/measured-layouts.md#gallery-view
    private func fit(in room: Rect) -> Double {
        min(
            Self.largest,
            max(room.width, 1) * 0.5 / cardWidth,
            max(room.height, 1) / (cardHeight * Self.headroom))
    }

    /// How much taller than a card the room has to be for it to stand at its
    /// full size - the room the fan's lift and a turned card's corners need.
    private static var headroom: Double { 1.16 }

    /// How much bigger than its stated size a card may be drawn: about a third
    /// again, so one card does not become the page.
    private static var largest: Double { 1.375 }

    /// Where one card goes and how it is turned. With no shade view the shade
    /// is `PackedPlacement.unshaded`, the host seeing none of this side's views.
    private func place(
        _ index: Int,
        _ count: Int,
        _ room: Rect,
        _ shape: GalleryArrangement
    ) -> Placement {
        var placement = placed(Double(index) - at, count, room, shape)

        placement.shade = mask == nil
            ? PackedPlacement.unshaded
            : min(max(placement.shade, 0), 1)

        return placement
    }

    /// Where the card in front is drawn in the room: its placement taken
    /// through its shape's transform.
    private func front(in room: Rect, shape: GalleryArrangement) -> Rect {
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
        _ shape: GalleryArrangement
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

    /// A wheel: the one in the middle faces the user and the rest turn away,
    /// shrink and fade behind it.
    private func wheel(_ step: Double, _ room: Rect, _ fit: Double) -> Placement {
        let near = max(-2.4, min(2.4, step))
        let away = min(abs(near), 1.55) / 1.55

        // `turn` draws a turn about the vertical axis flat, the same on every
        // platform, where `.rotationY` is projected differently by each.
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

    /// A fan: the card in the middle stands tallest and the ones beside it lean
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

    /// A row, side by side, no wider than the room however many cards there are.
    private func row(_ step: Double, _ count: Int, _ room: Rect, _ fit: Double) -> Placement {
        let across = min(cardWidth * 0.64 * fit, room.width / Double(max(count, 1)))

        return Placement(
            card(room, up: 0, across: step * across),
            transform: .scale((0.58 + 0.16 * max(0, 1 - abs(step))) * fit),
            zIndex: order(step))
    }

    /// Which cards are drawn over which: the middle one nearest the user, the
    /// rest behind it by their distance from it.
    private func order(_ step: Double) -> Int {
        1000 - Int(min(abs(step), 99) * 100)
    }

    /// A card's rectangle: its stated size in the middle of the room, moved by
    /// the arithmetic. The fit is a scale, so the card's content shrinks with it.
    private func card(_ room: Rect, up: Double, across: Double) -> Rect {
        Rect(
            room.width / 2 + across - cardWidth / 2,
            room.height / 2 + up - cardHeight / 2,
            cardWidth,
            cardHeight)
    }

    /// The items and their card face, behind a class.
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

/// The run's watcher: a view of nothing that reads where the run is asked to
/// be, so the read rebuilds it and not the deck.
/// Design: docs/design/views/composition.md#a-watcher-is-a-view-of-its-own
private struct Turning: ContentView {
    /// Where the run is asked to be - ASKED here, so the read is this view's.
    let at: () -> Int

    /// The shape it is asked to stand in.
    let look: GalleryArrangement

    /// What a new position means: the run is sent there, and the author told.
    let turned: (Int) async throws -> Void

    /// What a new shape means.
    let wore: () async throws -> Void

    var content: any View {
        let position = at()

        return ColorBox(Color("#00000000"))
            .width(0)
            .height(0)
            .ignoresInput(true)
            .onChanged(position) { try await turned(position) }
            .onChanged(look) { try await wore() }
    }
}
