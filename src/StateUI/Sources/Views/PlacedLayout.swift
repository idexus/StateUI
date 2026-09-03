// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A LAYOUT OF THE AUTHOR'S OWN: a run of views, and one line of arithmetic
// saying where each of them goes and how it is turned.
//
//     PlacedLayout(cards, id: \.self, at: { index, count, room in
//         let turn = Double(index) - Double(count - 1) / 2
//         return Placement(
//             Rect(room.width / 2 - 60 + turn * 44, turn * turn * 6, 120, 170),
//             transform: .rotate(turn * 6)
//         )
//     }) { card in
//         CardFace(card)
//     }
//
// That is a fan. A ring, a spiral, a stack of receipts, a masonry of tiles, a
// timeline and a gallery whose cards turn away as they leave the middle are the
// same shape with different arithmetic - none of them is a layout any toolkit
// ships, and all of them are a few lines here.
//
// AND IT MOVES BY ITSELF. Where a child sits is a value like any other, so a
// card added to the run spreads the fan, one removed closes it, and a turn of
// the device flows every card to its new place - because the arithmetic is
// re-answered and the host's engine carries each child from where it was to
// where the answer now puts it. Nothing about that is written here.
//
// What it is made of is what this library's own list is made of: an
// AbsoluteLayout, positions in it, and a measurement to work them out from.
// One frame late on the first showing, because the room has to be measured
// before anything can be placed in it - and never again after that.

/// Views placed by arithmetic of the author's own. This library's own.
///
/// The `at` closure is the whole layout: given which view this is, how many
/// there are and how much room there is, it answers the `Placement` that view
/// gets. It is called again whenever the run changes or the room does, and what
/// it answers is where each child TRAVELS to - so a layout written this way is a
/// layout that moves, on every platform, without a word about animation
/// anywhere in it.
///
///     PlacedLayout(planets, id: \.name, at: { index, count, room in
///         let angle = Double(index) / Double(count) * 2 * .pi
///         let radius = min(room.width, room.height) / 2 - 40
///
///         return Placement(Rect(
///             room.width / 2 + cos(angle) * radius - 24,
///             room.height / 2 + sin(angle) * radius - 24,
///             48,
///             48))
///     }) { planet in
///         Ellipse().fill(planet.colour)
///     }
///
/// The rectangle is in DEVICE UNITS, measured from the layout's own top left. A
/// view is welcome to overlap another, sit outside the room, or be given the
/// same place as its neighbour - nothing here rearranges what the arithmetic
/// said, and `zIndex` is what settles which of two overlapping views is on top.
///
/// THE ARITHMETIC OWES ONE THING: on a side nothing CONSTRAINS, its answer has
/// to be bounded. A layout given no limit on an axis - one inside a scroller,
/// say - asks for whatever its children reach, and a placement free to sit
/// outside the room then reaches further the more room it is given: the room
/// grows the placements, the placements grow the room, and the pass never
/// settles. Where the parent states a size there is nothing to watch for, the
/// layout being the size it was given; where it does not, cap the answer. The
/// library's own `GalleryView` holds a card to 1.375 times its natural size
/// for exactly this reason.
public struct PlacedLayout<Items: RandomAccessCollection, Id: Hashable>: ContentView {
    /// One view being placed: which of the run it is, and what it stands in.
    ///
    /// Held together rather than passed as three arguments, so the closure a
    /// layout is written in reads as arithmetic rather than as a signature.
    private struct Slot {
        let identity: String
        let index: Int
        let item: Items.Element
    }

    /// What is placed, how it is identified, where it goes and what it looks
    /// like - behind a class, which is what stops the Mirror walk that adopts
    /// state boxes from recursing through the items.
    ///
    /// The walk descends through a view's stored properties to find the
    /// `@State` a nested view owns, and a layout's items are DATA rather than
    /// views: a run over a hundred records would have every field of every one
    /// of them visited on every render, to find state that is never there.
    /// Stopping at a reference is the walk's own rule.
    private let source: Source

    private var travel = Motion.inherited

    /// What is drawn OVER each placed view, worn at the opacity its placement
    /// gives as `shade`. Nothing, unless the layout was given one.
    private var mask: Element?

    /// The buses this layout follows BETWEEN renders. Empty where the
    /// placement is the tree's alone. See Core/Bus.swift.
    private let follows: [HostBus]

    /// The bus the run of placements rides on, where one does.
    private var run: Bus<PlacedRun>?

    /// A layout of the author's own.
    ///
    /// - Parameters:
    ///   - items: what to place, one view each.
    ///   - id: which part of an item is its identity - distinct across the
    ///     items, and stable while the item means the same view. It is what
    ///     lets a view keep its place, its state and its motion when the run
    ///     is added to, taken from or reordered.
    ///   - at: where a view goes and how it is turned: which of the run it is,
    ///     how many there are, and the room the layout was given.
    ///   - content: the view for one item.
    public init(
        _ items: Items,
        id: KeyPath<Items.Element, Id>,
        at: @escaping (_ index: Int, _ count: Int, _ room: Rect) -> Placement,
        content: @escaping (Items.Element) -> Element
    ) {
        self.source = Source(items: items, path: id, at: at, view: content)
        self.follows = []
    }

    /// A layout of the author's own placed by a BUS - one run of placements,
    /// worked out by an engine and written on the host's own frames.
    ///
    ///     @Bus private var run = PlacedRun()
    ///     @Bus private var room = Rect(0, 0, 0, 0)
    ///     @Bus private var across = AnimatedValue(0.0)
    ///
    ///     PlacedLayout(cards, id: \.name) { face($0) }
    ///         .placement($run)
    ///         .frame($room)
    ///         .engine(following: $across, $room) { _ in
    ///             run = PlacedRun(cards.indices.map { place($0, room) })
    ///         }
    ///
    /// NOTHING IS DESCRIBED WHEN THE CARDS MOVE. The engine runs on the
    /// display's own frames, the run it writes crosses as numbers, and the host
    /// puts the views where they say - so a hand dragging a run of cards costs
    /// the arithmetic and the writes, and no render at all.
    ///
    /// The other form asks the arithmetic per RENDER and is the plainer thing
    /// to write; this one is what a value the READER is moving needs, there
    /// being no render to hang it on.
    ///
    /// - Parameters:
    ///   - items: what to place, one view each.
    ///   - id: which part of an item is its identity - distinct across the
    ///     items, and stable while the item means the same view.
    ///   - content: the view for one item.
    public init(
        _ items: Items,
        id: KeyPath<Items.Element, Id>,
        content: @escaping (Items.Element) -> Element
    ) {
        self.source = Source(items: items, path: id, at: nil, view: content)
        self.follows = []
    }

    /// A layout of the author's own that FOLLOWS values the platform moves
    /// many times a second - a scroller's offset, a finger's drag - without
    /// the interface being described again for any of them.
    ///
    ///     @Bus private var across = 0.0
    ///     @Bus private var turn = 0.0
    ///
    ///     PlacedLayout(cards, id: \.name, following: $across, $turn, at: place) { card in
    ///         CardFace(card)
    ///     }
    ///
    /// THE ARITHMETIC IS THE SAME ONE, unchanged: `at` reads those values by
    /// their own names, exactly as it would read anything else, and reading a
    /// channel records nothing - so nothing is rebuilt when one moves. What
    /// `following` says is only WHICH of them, when they move, should have
    /// this arithmetic run again.
    ///
    /// A render describes the views exactly where the arithmetic puts them;
    /// between renders the host calls the same closure on its own frames and
    /// writes the answers straight onto the controls. Every part of a
    /// placement follows: where the view goes, how it is turned, how opaque it
    /// is and which is drawn over which.
    ///
    /// - Parameters:
    ///   - items: what to place, one view each.
    ///   - id: which part of an item is its identity - distinct across the
    ///     items, and stable while the item means the same view.
    ///   - value: a channel whose movement re-runs the arithmetic.
    ///   - more: any others it also follows.
    ///   - at: where a view goes and how it is turned: which of the run it is,
    ///     how many there are, and the room the layout was given.
    ///   - content: the view for one item.
    public init(
        _ items: Items,
        id: KeyPath<Items.Element, Id>,
        following value: HostBus,
        _ more: HostBus...,
        at: @escaping (_ index: Int, _ count: Int, _ room: Rect) -> Placement,
        content: @escaping (Items.Element) -> Element
    ) {
        self.source = Source(items: items, path: id, at: at, view: content)
        self.follows = [value] + more
    }

    /// The bus this layout's placements ride on. This library's own.
    ///
    ///     PlacedLayout(cards, id: \.name) { face($0) }.placement($run)
    ///
    /// One `PlacedRun` a view, in the order they stand in, written by an
    /// engine and worn by the host on its own frames. A run shorter than the
    /// views leaves the rest where they were; one longer is read as far as
    /// there are views to wear it.
    ///
    /// THE LAW IS THE RUN'S, not this layout's: `PlacedRun(placements)` puts
    /// the views where it says AT ONCE, which is what arithmetic re-run every
    /// frame wants, and a run written with a law travels there - so a shape
    /// that changes crosses while a finger goes on moving the cards.
    /// `.motion(_:)` on the layout is what a run of `.inherited` travels by.
    ///
    /// - Parameter bus: the run of placements.
    /// - Returns: the layout, placed by that bus.
    public func placement(_ bus: Bus<PlacedRun>) -> PlacedLayout {
        var copy = self
        copy.run = bus
        return copy
    }

    /// How the views TRAVEL when the arithmetic puts them somewhere new.
    /// This library's own.
    ///
    ///     PlacedLayout(cards, id: \.self, at: place) { … }.motion(.none)
    ///
    /// A layout of your own moves like every other one: a card given a new
    /// place travels to it, at whatever the application says. `.none` holds
    /// them still, which is what a placement worked out from something the
    /// reader is DRAGGING wants - the arithmetic is re-answered on every
    /// report, and a card a fifth of a second behind the hand is a card that
    /// lags. It reaches the placed views themselves as well as their places, so
    /// a turn and a fade follow the hand exactly as a position does.
    ///
    /// - Parameter motion: how the views travel to a new place.
    /// - Returns: the layout, moving that way.
    public func motion(_ motion: Motion) -> PlacedLayout {
        var copy = self
        copy.travel = motion
        return copy
    }

    /// What to draw OVER a placed view to darken it, worn at the opacity the
    /// arithmetic answered as `Placement.shade`. This library's own.
    ///
    ///     PlacedLayout(cards, id: \.name, following: $turned, at: place) {
    ///         face($0)
    ///     }
    ///     .shade(BoxView(.black).cornerRadius(14))
    ///
    /// One view, built once and drawn over every placed view - so it is a
    /// SHAPE rather than a picture: a shade with the wrong corners shows its
    /// own square edges over a rounded card, and only the author knows which
    /// corners the card has.
    ///
    /// Without this the arithmetic's `shade` reaches nothing, and a run that
    /// sends its far views into the background does it with `opacity` alone -
    /// which is the right answer where the views do not overlap and the wrong
    /// one where they do, a faded view showing the view behind it.
    ///
    /// - Parameter view: what to draw over each placed view.
    /// - Returns: the layout, shaded.
    public func shade(_ view: Element) -> PlacedLayout {
        var copy = self
        copy.mask = view
        return copy
    }

    /// The views, each placed the way the arithmetic put it - or, where a bus
    /// places them, wrapped and left to the host.
    public var content: Element {
        let held = source

        let slots = held.items.enumerated().map { offset, item in
            Slot(
                identity: String(describing: item[keyPath: held.path]),
                index: offset,
                item: item)
        }

        let build = held.view

        if let bus = run {
            let over = mask

            // NOT ONE PROPERTY OF A PLACEMENT IS DESCRIBED. The views are
            // wrapped and handed over; where each of them goes arrives on the
            // bus, on the host's own frames, and no render mentions it.
            return AbsoluteLayout {
                ForEach(slots, id: \.identity) { slot in
                    PlacedLayout.wrapped(build(slot.item), under: over)
                }
            }
            .motion(travel)
            .setValue(.absoluteLayoutBounds, on: bus, mode: .out, kind: .placement)
        }

        guard let place = held.at else { return AbsoluteLayout {} }

        let moves = travel
        let over = mask

        let followed = follows

        // THE ABSENCE OF A SHADE IS A NUMBER, because the host cannot see this
        // side's views: it is handed a run of doubles and the placed control,
        // and `unshaded` is what tells it there is no shade view under one.
        // Written here rather than left to the author's arithmetic, which
        // answers 0 for a view that wears none of a shade the layout HAS.
        let arithmetic: PlacementRule? = follows.isEmpty ? nil : { index, count, room in
            var placement = place(index, count, room)

            placement.shade = over == nil
                ? PackedPlacement.unshaded
                : min(max(placement.shade, 0), 1)

            return placement
        }

        return FrameReader { room in
            // ASKED FOR ALL AT ONCE, because the drawing order is a fact about
            // the whole run rather than about any one view of it.
            let placements = slots.map { place($0.index, slots.count, room) }
            let order = Placement.drawingOrder(of: placements)

            following(
                AbsoluteLayout {
                    ForEach(slots, id: \.identity) { slot in
                        PlacedLayout.placed(
                            build(slot.item),
                            at: placements[slot.index],
                            drawnAt: order[slot.index],
                            moving: moves,
                            under: over)
                    }
                }
                .motion(moves),
                followed,
                arithmetic)
        }
    }

    /// What the layout was handed, behind a reference. See `source`.
    private final class Source {
        /// What to place, one view each.
        let items: Items

        /// Which part of an item is its identity.
        let path: KeyPath<Items.Element, Id>

        /// Where a view goes and how it is turned, or nothing where a BUS
        /// says instead.
        let at: ((Int, Int, Rect) -> Placement)?

        /// The view for one item.
        let view: (Items.Element) -> Element

        /// What the initializers were handed.
        init(
            items: Items,
            path: KeyPath<Items.Element, Id>,
            at: ((Int, Int, Rect) -> Placement)?,
            view: @escaping (Items.Element) -> Element
        ) {
            self.items = items
            self.path = path
            self.at = at
            self.view = view
        }
    }

    /// One view inside the container the host writes a placement onto.
    ///
    /// ALWAYS A CONTAINER, shaded or not, and that is what keeps the two
    /// writers apart: everything a placement says - where the view is, how it
    /// is turned, how opaque - is written onto this wrapper, so an author's own
    /// `.opacity` or `.rotation` on the face beneath is theirs alone and is
    /// never overwritten by a frame of arithmetic.
    ///
    /// A shade is the SECOND child, which is the whole of how the host finds
    /// one - both children being this library's own, their order is its
    /// guarantee rather than the author's.
    private static func wrapped(_ view: Element, under mask: Element?) -> Element {
        guard let mask else { return Grid { view } }

        return Grid {
            view
            ModifiedContent(node: mask.body)
        }
    }

    /// One view wearing its placement, drawn at the rank the whole run gave it.
    ///
    /// The law is written on the view only where it is not the inherited one:
    /// a placement's turn and fade are ordinary properties, so they travel
    /// under whatever the application says unless this layout was told
    /// otherwise, and saying so on every child of every run would be bytes
    /// spent to repeat the default.
    ///
    /// A SHADED LAYOUT PLACES A GRID, never the view itself: the placement goes
    /// on the grid and the shade is its SECOND child, which is the whole of how
    /// the host finds one. So the two children are this library's own and their
    /// order is its guarantee, not the author's.
    private static func placed(
        _ view: Element,
        at placement: Placement,
        drawnAt rank: Int,
        moving: Motion,
        under mask: Element?
    ) -> Element {
        let placed: Element = mask.map { shade in
            Grid {
                view
                ModifiedContent(node: shade.body)
                    .opacity(min(max(placement.shade, 0), 1))
            }
        } ?? view

        let content = ModifiedContent(node: placed.body)
            .absoluteLayoutBounds(placement.bounds)
            .transform(placement.transform)
            .opacity(placement.opacity)
            .zIndex(rank)

        return moving == .inherited ? content : content.motion(moving)
    }
}
