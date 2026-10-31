// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A run of cards the user swipes through, in a shape one word chooses: a motion layout with the arithmetic of a
// wheel, a fan, a row and a deck, its phase the card in front.
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
///     .onItemActivated { title in open(title) }
///
/// The initializer is the card's face, one card per item; where a card goes
/// and which way it faces is the arrangement's. Give the gallery a bounded
/// size, as it has none of its own - a `.height`, or a `.fill` row of a Grid -
/// and the cards are fitted to it.
///
/// A swipe settles on a card, and `.position(_:)` says which; assigning it
/// moves the run. A tap on the card in front activates it, and
/// `.onItemActivated` hears its identity. No
/// view is rebuilt while the run moves: the one render is the card changing.
public struct GalleryView<Items: RandomAccessCollection, ID: Hashable>: View {
    // State first: boxes are adopted by path, and the card faces stored below
    // may carry boxes of their own.
    // Design: docs/design/views/composition.md#state-declared-first

    /// Which card is in the middle, where no binding was lent.
    @State private var shown = 0

    /// Which card is held down, by its identity: the gallery shows the press on
    /// the card's face, beneath the placement the run writes every frame.
    @State private var dipping: ID?

    /// Where the run stands, a card a unit: the layout's phase, which the host
    /// walks - a position written travels there through it.
    @State private var turn = 0.0

    /// Who starts the runs of what `onPositionChanged` asked for, ended with the gallery.
    @State private var positionRuns = RunOwner()

    /// The items and their card face, behind a class so the state walk stops.
    private let source: Source

    /// Where the middle card is written, when an author lent a binding.
    private var pin: Binding<Int>?

    /// What runs when the middle card changes, beside any binding, through its gate.
    private var moved: ValueHandler<Int>?

    /// What runs when the user activates the card in front, with its identity, through its gate.
    private var activated: ValueHandler<ID>?

    /// Which shape the cards stand in.
    private var look = GalleryArrangement.default

    /// How wide a card is, in device units.
    private var cardWidth = 176.0

    /// And how tall.
    private var cardHeight = 248.0

    /// Whether the user may swipe at all.
    private var swipes = true

    /// How a throw of the hand goes on, where the author says.
    private var thrown: Motion?

    /// What stands in when there are no items at all.
    private var empty: (any View)?

    /// What is drawn over a far card to darken it. See `shade(_:amount:)`.
    private var mask: (any View)?

    /// How far the shade goes, from 0 to 1.
    private var shades = 1.0

    /// How far the fade goes, where the author said. See `fade`.
    private var fades: Double?

    /// How each card moves as a body of the gallery's world, where the author said. See `itemBody`.
    private var cardBody: LayoutBody?

    /// One card per item, the item its identity.
    ///
    ///     GalleryView(covers) { cover in
    ///         Image(cover)
    ///     }
    ///
    /// - Parameters:
    ///   - items: What the gallery shows, one card each.
    ///   - content: The card's face, run for every item.
    public init<Content: View>(
        _ items: Items,
        @ViewBuilder content: @escaping (Items.Element) -> Content
    ) where Items.Element: Hashable, ID == Items.Element {
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
    public init<Content: View>(
        _ items: Items,
        id: KeyPath<Items.Element, ID>,
        @ViewBuilder content: @escaping (Items.Element) -> Content
    ) {
        source = Source(items: items, path: id, card: { content($0).node })
    }

    /// Which shape the cards stand in - a wheel unless said.
    ///
    ///     GalleryView(albums) { … }.arrangement(.fan)
    ///
    /// - Parameter arrangement: the arrangement.
    /// - Returns: the gallery, in that shape.
    public func arrangement(_ arrangement: GalleryArrangement) -> Self {
        var copy = self
        copy.look = arrangement
        return copy
    }

    /// Which card is in the middle, counting from 0, two-way: a swipe writes
    /// the card it settled on.
    ///
    ///     @State private var shown = 0
    ///
    ///     GalleryView(albums) { … }.position($shown)
    ///     Text(albums[shown].title)
    ///
    /// Assigning it moves the run. A gallery nobody lends a binding to keeps
    /// the card itself and still settles on one.
    ///
    /// - Parameter state: where the middle card is written and read.
    /// - Returns: the gallery, keeping its card there.
    public func position(_ state: Binding<Int>) -> Self {
        var copy = self
        copy.pin = state
        return copy
    }

    /// Runs when another card comes to the middle, swiped or assigned, with
    /// its index.
    ///
    /// - Parameter handler: what to run, given the card's index.
    /// - Returns: the gallery, telling that handler.
    public func onPositionChanged(_ handler: @escaping @MainActor (Int) throws -> Void) -> Self {
        var copy = self
        copy.moved = ValueHandler(step: handler)
        return copy
    }

    /// The same, with a handler that awaits: its `policy` says what another card coming to the middle does while
    /// a run is under way.
    public func onPositionChanged(_ policy: GatePolicy, _ handler: @escaping ValueEventHandler<Int>) -> Self {
        var copy = self
        copy.moved = ValueHandler(run: handler, gate: .own(policy))
        return copy
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onPositionChanged(gate: Gate, _ handler: @escaping ValueEventHandler<Int>) -> Self {
        var copy = self
        copy.moved = ValueHandler(run: handler, gate: .shared(gate))
        return copy
    }

    /// Hears the user open the card in front, handed its identity.
    ///
    ///     GalleryView(groups, id: \.route) { … }
    ///         .position($shown)
    ///         .onItemActivated { route in open(route) }
    ///
    /// A tap lands on the card in front as its shape draws it, whether the
    /// user may swipe the run or not.
    ///
    /// - Parameter handler: what to run, given the card's identity.
    /// - Returns: the gallery, answering its card's activation.
    public func onItemActivated(_ handler: @escaping @MainActor (ID) throws -> Void) -> Self {
        var copy = self
        copy.activated = ValueHandler(step: handler)
        return copy
    }

    /// The same, with a handler that awaits - opening a page does: its `policy` says what opening the card again
    /// does while a run is under way.
    public func onItemActivated(_ policy: GatePolicy, _ handler: @escaping ValueEventHandler<ID>) -> Self {
        var copy = self
        copy.activated = ValueHandler(run: handler, gate: .own(policy))
        return copy
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onItemActivated(gate: Gate, _ handler: @escaping ValueEventHandler<ID>) -> Self {
        var copy = self
        copy.activated = ValueHandler(run: handler, gate: .shared(gate))
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

    /// How the run goes on when the user lets go of it with speed - how far a
    /// throw carries, and how it slows - as any motion says it.
    ///
    ///     .throwMotion(.spring(response: .milliseconds(500), damping: 0.8))
    ///
    /// - Parameter motion: eased, its length says how far a throw carries and
    ///   its curve how it slows; a spring settles as springs do. Either sets
    ///   out at the hand's speed.
    /// - Returns: the gallery, thrown that way.
    public func throwMotion(_ motion: Motion) -> Self {
        var copy = self
        copy.thrown = motion
        return copy
    }

    /// How each card moves as a body of the gallery's world: a body following its place lags behind it as the
    /// gallery turns, and settles back onto it.
    ///
    ///     .itemBody(.followsLayout(.spring(response: .milliseconds(300), damping: 0.8)))
    ///
    /// - Parameter body: the body every card is, as `layoutBody(_:)` gives one view of a motion layout.
    /// - Returns: the gallery, its cards moving so.
    public func itemBody(_ body: LayoutBody) -> Self {
        var copy = self
        copy.cardBody = body
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
    public func emptyView(_ view: some View) -> Self {
        var copy = self
        copy.empty = view
        return copy
    }

    /// What to draw over a card to send it into the background, and how far.
    ///
    ///     GalleryView(covers, id: \.name) { face($0) }
    ///         .shade(
    ///             Rectangle()
    ///                 .fill(Color(hex: 0x000000))
    ///                 .cornerRadius(14))
    ///
    /// A shade darkens a far card without showing the card behind it, as
    /// fading would; the card in front wears none of it. Give the view the
    /// corners the card has. With a shade the fade drops to a quarter, unless
    /// `fade(_:)` says otherwise.
    ///
    /// - Parameters:
    ///   - view: what to draw over each card.
    ///   - amount: how dark the furthest card goes, from 0 (not at all) to 1
    ///     (as far as the shape says). The whole of it, unless said.
    /// - Returns: the gallery, darkening its far cards.
    public func shade(_ view: some View, amount: Double = 1) -> Self {
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
    ///         .shade(
    ///             Rectangle()
    ///                 .fill(Color(hex: 0x000000))
    ///                 .cornerRadius(14))
    ///         .fade(0)
    ///
    /// - Parameter amount: how far a far card fades.
    /// - Returns: the gallery, fading that much.
    public func fade(_ amount: Double) -> Self {
        var copy = self
        copy.fades = Self.fraction(amount, "fade(_:)")
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

    /// The cards, the shape they stand in, and the hand that turns them.
    public var body: some View {
        let items = source.items
        let count = items.count

        // The empty view is held as `any View`, so every answer goes as a node.
        if count == 0, let empty {
            return AnyView(empty)
        }

        // Locals rather than `self`, which holds a class.
        // Design: docs/design/views/composition.md#handlers-capture-locals
        let showns = _shown
        let dips = _dipping
        let turns = _turn
        let pin = pin
        let moved = moved
        let positionRuns = positionRuns
        let path = source.path
        let make = source.card
        let shape = look
        let (width, height) = (cardWidth, cardHeight)
        let body = cardBody

        // The position, read in a closure: read here, it would make this body a reader, and every card crossed
        // would rebuild the deck.
        // Design: docs/design/views/composition.md#a-watcher-is-a-view-of-its-own
        let asked = { min(max(pin?.wrappedValue ?? showns.wrappedValue, 0), count - 1) }

        var layout = MotionLayout(items, id: path, parameters: turns.projectedValue) { item in
            // The face in a holder of its own, so the press on it is not overwritten by the placement written on
            // the holder every frame. The holder is the card's size: a card the run has not placed yet would fill
            // the room.
            let card = Grid {
                AnyView(node: make(item))
                    // Which card is pressed, never which is in front.
                    .scale(dips.wrappedValue == item[keyPath: path] ? Self.dip : 1)
                    .motion(Self.pressing)
            }
            .width(width)
            .height(height)
            if let body { card.layoutBody(body) } else { card }
        } placements: { room, parameters, segmentStart in
            (0..<count).map { place(Double($0) - parameters, setOut: Double($0) == segmentStart, count, room, shape) }
        }
        // The cards stand in reading order, as a stack's views do.
        .mirrorsRightToLeft(true)
        // A card the hand names is the position at once, in the frame that names it.
        .onNamed { turned in
            let card = min(max(Int(turned.rounded()), 0), count - 1)

            if let pin {
                if pin.wrappedValue != card { pin.wrappedValue = card }
            } else if showns.wrappedValue != card {
                showns.wrappedValue = card
            }
        }

        // The hand carries the card in front, however big the room draws it; a deck is swiped a card at a time.
        if swipes {
            let input = shape == .deck ? LayoutInput.swipe(.horizontal) : .scroll(.horizontal)
            layout = layout.axis(\.self, input: input, range: 0...Double(max(count - 1, 0)), snaps: .every(1))
            if let thrown { layout = layout.throwMotion(thrown) }
        }

        // The shade sits beside the press: the card that dips wears none.
        if let mask { layout = layout.shade(mask) }

        // The tap, answered on the card in front: the press shows, and the card is back at its size, before the
        // activation's own work, which usually builds a page.
        if let activated {
            let tapped: ValueEventHandler<Items.Element> = { item in
                let front = items[items.index(items.startIndex, offsetBy: asked())]

                guard item[keyPath: path] == front[keyPath: path] else { return }

                dips.wrappedValue = item[keyPath: path]

                try await Task.sleep(for: .milliseconds(Self.held))

                dips.wrappedValue = nil

                try await activated.run(item[keyPath: path])
            }
            switch activated.gate {
            case .own(let policy): layout = layout.onItemTapped(policy, tapped)
            case .shared(let gate): layout = layout.onItemTapped(gate: gate, tapped)
            }
        }

        let deck = Grid {
            layout

            // The watcher of the position, a view of its own beside the deck, so reading it rebuilds none of the
            // cards: a position written sends the run there.
            Watcher(at: asked) { position in
                if turns.wrappedValue != Double(position) { turns.wrappedValue = Double(position) }

                guard let moved else { return }

                moved.gate.runs(for: positionRuns).start(
                    { try await moved.run(position) }, moved.gate.policy, payload: nil, owner: positionRuns)
            }
        }
        // The run starts where the position stands, with no journey to it.
        .onCreated { turns.projectedValue.journey.snap(to: Double(asked())) }
        // What the position asked for ends with the gallery.
        .onDestroying { positionRuns.orphan() }

        return AnyView(deck)
    }

    /// How small the card in front is drawn while it is held down.
    private static var dip: Double { 0.96 }

    /// How long the card is held down before the tap's own work begins, in
    /// milliseconds - long enough for the press to be seen at all.
    private static var held: Int { 60 }

    /// How the press animates, down and back: short, as an answer to a finger.
    private static var pressing: Motion { .eased(.milliseconds(50), .cubicOut) }

    /// How far a far card fades unless said: all of it, or a quarter where a
    /// shade does the rest.
    private var fade: Double { fades ?? (mask == nil ? 1 : 0.25) }

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

    /// Where one card goes and how it is turned, `step` cards from the one in front - the one the run's motion set
    /// out from where `setOut`. With no shade view the shade is `Placement.unshaded`, the host seeing none of
    /// this side's views.
    private func place(
        _ step: Double,
        setOut: Bool,
        _ count: Int,
        _ room: Rect,
        _ shape: GalleryArrangement
    ) -> Placement {
        var placement = placed(step, setOut: setOut, count, room, shape)

        placement.shade = mask == nil
            ? Placement.unshaded
            : min(max(placement.shade, 0), 1)

        return placement
    }

    /// Where a card goes, however far it stands from the one in front.
    private func placed(
        _ step: Double,
        setOut: Bool,
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

        case .deck:
            return deck(step, setOut: setOut, room, fit)

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

    /// A deck: the card in front whole and straight, the others behind it
    /// peeking out either side, smaller and turned the farther they are. The
    /// card the run set out from goes out the way it goes, over the others,
    /// until it stands beside the deck, then tucks under the next.
    /// Design: docs/design/views/measured-layouts.md#gallery-view
    private func deck(_ step: Double, setOut: Bool, _ room: Rect, _ fit: Double) -> Placement {
        let side: Double = step < 0 ? -1 : 1
        let behind = min(abs(step), 4)
        let leaving = setOut && abs(step) < 1
        let outward = leaving && abs(step) < 0.8
        let out = leaving ? (outward ? abs(step) / 0.8 : (1 - abs(step)) / 0.2) : 0

        return Placement(
            card(room, up: behind * 3 * fit, across: side * (behind * 14 + out * cardWidth * 1.05) * fit),
            transform: .rotate(side * (behind * 2.5 + out * 12)).scale((1 - behind * 0.03) * fit),
            opacity: min(max(5 - abs(step), 0), 1),
            shade: min(behind / 4, 0.5) * shades,
            zIndex: outward ? 2000 : order(step))
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
        let path: KeyPath<Items.Element, ID>

        /// The card's face, as a node.
        let card: (Items.Element) -> Node

        /// What the initializers were handed.
        init(
            items: Items,
            path: KeyPath<Items.Element, ID>,
            card: @escaping (Items.Element) -> Node
        ) {
            self.items = items
            self.path = path
            self.card = card
        }
    }
}

/// A watcher: a view of nothing that reads one value, so the read rebuilds it and not the deck.
/// Design: docs/design/views/composition.md#a-watcher-is-a-view-of-its-own
private struct Watcher<Value: Equatable>: View {
    /// The value - ASKED here, so the read is this view's.
    let at: () -> Value

    /// What a new value means.
    let turned: (Value) -> Void

    var body: some View {
        let value = at()

        return Rectangle()
            .fill(.transparent)
            .width(0)
            .height(0)
            .ignoresInput(true)
            .onChanged(value) { turned(value) }
    }
}
