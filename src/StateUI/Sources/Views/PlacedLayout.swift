// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A LAYOUT OF THE AUTHOR'S OWN: a run of views, and one line of arithmetic
// saying where each of them goes.
//
//     Placed(cards, id: \.self, at: { index, count, room in
//         let turn = Double(index) - Double(count - 1) / 2
//         return Rect(room.width / 2 - 60 + turn * 44, turn * turn * 6, 120, 170)
//     }) { card in
//         CardFace(card)
//     }
//
// That is a fan. A ring, a spiral, a stack of receipts, a masonry of tiles and
// a timeline are the same shape with different arithmetic - none of them is a
// layout any toolkit ships, and all of them are a few lines here.
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
/// there are and how much room there is, it answers the rectangle that view
/// gets. It is called again whenever the run changes or the room does, and
/// what it answers is where each child TRAVELS to - so a layout written this
/// way is a layout that moves, on every platform, without a word about
/// animation anywhere in it.
///
///     Placed(planets, id: \.name, at: { index, count, room in
///         let angle = Double(index) / Double(count) * 2 * .pi
///         let radius = min(room.width, room.height) / 2 - 40
///         return Rect(
///             room.width / 2 + cos(angle) * radius - 24,
///             room.height / 2 + sin(angle) * radius - 24,
///             48,
///             48)
///     }) { planet in
///         Ellipse().fill(planet.colour)
///     }
///
/// The rectangle is in DEVICE UNITS, measured from the layout's own top left.
/// A view is welcome to overlap another, sit outside the room, or be given the
/// same place as its neighbour - nothing here rearranges what the arithmetic
/// said.
public struct Placed<Items: RandomAccessCollection, Id: Hashable>: ContentView {
    /// One view being placed: which of the run it is, and what it stands in.
    ///
    /// Held together rather than passed as three arguments, so the closure a
    /// layout is written in reads as arithmetic rather than as a signature.
    private struct Slot {
        let identity: String
        let index: Int
        let item: Items.Element
    }

    private let items: Items
    private let id: KeyPath<Items.Element, Id>
    private let at: (Int, Int, Rect) -> Rect
    private let view: (Items.Element) -> Element
    private var travel = Motion.inherited

    /// A layout of the author's own.
    ///
    /// - Parameters:
    ///   - items: what to place, one view each.
    ///   - id: which part of an item is its identity - distinct across the
    ///     items, and stable while the item means the same view. It is what
    ///     lets a view keep its place, its state and its motion when the run
    ///     is added to, taken from or reordered.
    ///   - at: where a view goes: which of the run it is, how many there are,
    ///     and the room the layout was given. In device units from the
    ///     layout's own top left.
    ///   - content: the view for one item.
    public init(
        _ items: Items,
        id: KeyPath<Items.Element, Id>,
        at: @escaping (_ index: Int, _ count: Int, _ room: Rect) -> Rect,
        content: @escaping (Items.Element) -> Element
    ) {
        self.items = items
        self.id = id
        self.at = at
        self.view = content
    }

    /// How the views TRAVEL when the arithmetic puts them somewhere new.
    /// This library's own.
    ///
    ///     Placed(cards, id: \.self, at: place) { … }.motion(.none)
    ///
    /// A layout of your own moves like every other one: a card given a new
    /// place travels to it, at whatever the application says. `.none` holds
    /// them still, which is what a placement worked out from something the
    /// reader is DRAGGING wants - the arithmetic is re-answered on every
    /// report, and a card a fifth of a second behind the hand is a card that
    /// lags.
    ///
    /// - Parameter motion: how the views travel to a new place.
    /// - Returns: the layout, moving that way.
    public func motion(_ motion: Motion) -> Placed {
        var copy = self
        copy.travel = motion
        return copy
    }

    /// The views, each at the place the arithmetic gave it.
    public var content: Element {
        let slots = items.enumerated().map { offset, item in
            Slot(
                identity: String(describing: item[keyPath: id]),
                index: offset,
                item: item)
        }

        let place = at
        let build = view

        let moves = travel

        return FrameReader { room in
            AbsoluteLayout {
                ForEach(slots, id: \.identity) { slot in
                    ModifiedContent(node: build(slot.item).body)
                        .absoluteLayoutBounds(place(slot.index, slots.count, room))
                }
            }
            .motion(moves)
        }
    }
}
