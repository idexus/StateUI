// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A LAYOUT OF THE AUTHOR'S OWN: a run of views, and one line of arithmetic
// saying where each of them goes and how it is turned.
//
//     @DrivenState private var fan = PlacedRun()
//     @DrivenState private var room = Rect(0, 0, 0, 0)
//
//     PlacedLayout(cards, id: \.self) { card in
//         CardFace(card)
//     }
//     .placement($fan)
//     .frame($room)
//     .engine(following: $room) { _ in
//         fan = PlacedRun(cards.indices.map { index in
//             let turn = Double(index) - Double(cards.count - 1) / 2
//             return Placement(
//                 Rect(room.width / 2 - 60 + turn * 44, turn * turn * 6, 120, 170),
//                 transform: .rotate(turn * 6))
//         })
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
// WHERE THE ARITHMETIC RUNS is the host's own frames, never a render: the
// engine reads the values it follows, writes one placement a view, and the
// host wears them. So a run of cards under a finger costs the sums and the
// writes and no description at all.
//
// What it is made of is what this library's own list is made of: an
// AbsoluteLayout and positions in it. One frame late on the first showing,
// because the room has to be measured before anything can be placed in it -
// and never again after that.

/// Views placed by arithmetic of the author's own. This library's own.
///
/// The engine is the whole layout: given the values it follows, it answers one
/// `Placement` per view - where that view goes, how it is turned, how opaque it
/// is and which is drawn over which - and writes them as a `PlacedRun` on the
/// number this layout is placed by. It runs again whenever one of those values
/// moves, and what it answers is where each child TRAVELS to, so a layout
/// written this way is a layout that moves, on every platform, without a word
/// about animation anywhere in it.
///
///     @DrivenState private var ring = PlacedRun()
///     @DrivenState private var room = Rect(0, 0, 0, 0)
///
///     PlacedLayout(planets, id: \.name) { planet in
///         Ellipse().fill(planet.colour)
///     }
///     .placement($ring)
///     .frame($room)
///     .engine(following: $room) { _ in
///         ring = PlacedRun(planets.indices.map { index in
///             let angle = Double(index) / Double(planets.count) * 2 * .pi
///             let radius = min(room.width, room.height) / 2 - 40
///
///             return Placement(Rect(
///                 room.width / 2 + cos(angle) * radius - 24,
///                 room.height / 2 + sin(angle) * radius - 24,
///                 48,
///                 48))
///         })
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

    /// The state the run of placements rides on, where one does.
    private var run: Binding<PlacedRun>?

    /// A layout of the author's own placed by a DRIVEN STATE - one run of placements,
    /// worked out by an engine and written on the host's own frames.
    ///
    ///     @DrivenState private var run = PlacedRun()
    ///     @DrivenState private var room = Rect(0, 0, 0, 0)
    ///     @DrivenState private var across = AnimatedValue(0.0)
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
    /// - Parameters:
    ///   - items: what to place, one view each.
    ///   - id: which part of an item is its identity - distinct across the
    ///     items, and stable while the item means the same view. It is what
    ///     lets a view keep its place, its state and its motion when the run
    ///     is added to, taken from or reordered.
    ///   - content: the view for one item.
    public init(
        _ items: Items,
        id: KeyPath<Items.Element, Id>,
        content: @escaping (Items.Element) -> Element
    ) {
        self.source = Source(items: items, path: id, view: content)
    }

    /// The state this layout's placements ride on. This library's own.
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
    /// - Parameter number: the run of placements.
    /// - Returns: the layout, placed by that number.
    public func placement(_ number: Binding<PlacedRun>) -> PlacedLayout {
        var copy = self
        copy.run = number
        return copy
    }

    /// How the views TRAVEL when the arithmetic puts them somewhere new.
    /// This library's own.
    ///
    ///     PlacedLayout(cards, id: \.self) { … }.placement($run).motion(.none)
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
    ///     PlacedLayout(cards, id: \.name) { face($0) }
    ///         .placement($run)
    ///         .shade(BoxView(.black).cornerRadius(14))
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

    /// The views, each placed the way the arithmetic put it - or, where a number
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
        let over = mask

        // NOT ONE PROPERTY OF A PLACEMENT IS DESCRIBED. The views are wrapped
        // and handed over; where each of them goes arrives on the state, on the
        // host's own frames, and no render mentions it.
        let views = AbsoluteLayout {
            ForEach(slots, id: \.identity) { slot in
                PlacedLayout.wrapped(build(slot.item), under: over)
            }
        }
        .motion(travel)

        guard let number = run else {
            // A LAYOUT IS WHAT PLACES ITS VIEWS, so one given no state places
            // none of them: they are drawn stacked at its own top left, which
            // is what an AbsoluteLayout does with children it was told nothing
            // about. Said out loud, because the screen alone reads as a view
            // that failed to draw.
            complain("PlacedLayout was given no .placement(_:), so nothing "
                + "says where its views go. They are drawn at its top left.")

            return views
        }

        return views.setValue(.absoluteLayoutBounds, on: number, mode: .out, kind: .placement)
    }

    /// What the layout was handed, behind a reference. See `source`.
    private final class Source {
        /// What to place, one view each.
        let items: Items

        /// Which part of an item is its identity.
        let path: KeyPath<Items.Element, Id>

        /// The view for one item.
        let view: (Items.Element) -> Element

        /// What the initializer was handed.
        init(
            items: Items,
            path: KeyPath<Items.Element, Id>,
            view: @escaping (Items.Element) -> Element
        ) {
            self.items = items
            self.path = path
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
}
