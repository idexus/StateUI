// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A scroll laid OVER a run of views, read as a channel rather than shown.
/// This library's own.
///
///     @Channel private var across = 0.0
///
///     ScrollReader(across: Double(cards.count - 1) * 90) {
///         PlacedLayout(cards, id: \.name, following: $across, at: place) { card in
///             CardFace(card)
///         }
///     }
///     .scrollX($across)
///     .snapInterval(90)
///
/// What it holds is not scrolled: the views stay where their own arithmetic
/// puts them, and what moves is a NUMBER - the offset of an empty scroller
/// lying over them, written into a channel. A layout following that channel
/// is then put where its arithmetic now says, frame by frame, with no view
/// built and no message sent.
///
/// A SCROLLER RATHER THAN A DRAG, on purpose: a finger drag, a two-finger
/// trackpad swipe and a mouse wheel are ONE thing to a scroller and three
/// different things to everything else, so all three move the run and the
/// platform's own snapping is what settles it.
///
/// How far it goes is how far BEYOND the room it can be scrolled, in device
/// units - `across: 540` on a room 300 wide is a run 840 long - so what an
/// author states is the distance the arithmetic is written against rather
/// than a size that depends on the screen.
public struct ScrollReader: ContentView {
    private let across: Double
    private let down: Double
    private let held: () -> [Element]

    private var reportsX: Channel<Double>?
    private var reportsY: Channel<Double>?
    private var interval: Double?
    private var from: Double?
    private var assigned: ControlState<ScrollView>?

    /// A run that scrolls ACROSS.
    ///
    /// - Parameters:
    ///   - across: how far beyond the room it can be scrolled sideways, in
    ///     device units.
    ///   - content: the views lying under it.
    public init(across: Double, @ViewBuilder content: @escaping () -> [Element]) {
        self.init(across: across, down: 0, content: content)
    }

    /// A run that scrolls DOWN.
    ///
    /// - Parameters:
    ///   - down: how far beyond the room it can be scrolled, in device units.
    ///   - content: the views lying under it.
    public init(down: Double, @ViewBuilder content: @escaping () -> [Element]) {
        self.init(across: 0, down: down, content: content)
    }

    /// A run that scrolls both ways.
    ///
    /// - Parameters:
    ///   - across: how far beyond the room it can be scrolled sideways, in
    ///     device units.
    ///   - down: how far beyond the room it can be scrolled, in device units.
    ///   - content: the views lying under it.
    public init(
        across: Double,
        down: Double,
        @ViewBuilder content: @escaping () -> [Element]
    ) {
        self.across = across
        self.down = down
        self.held = content
    }

    /// Where the offset ACROSS is written.
    ///
    /// - Parameter value: the channel it is written into.
    /// - Returns: the reader, reporting there.
    public func scrollX(_ value: Channel<Double>) -> ScrollReader {
        var copy = self
        copy.reportsX = value
        return copy
    }

    /// Where the offset DOWN is written.
    ///
    /// - Parameter value: the channel it is written into.
    /// - Returns: the reader, reporting there.
    public func scrollY(_ value: Channel<Double>) -> ScrollReader {
        var copy = self
        copy.reportsY = value
        return copy
    }

    /// Makes it come to rest on a GRID, the way a `ScrollView` does: the
    /// offsets it may stop at are `from`, `from + value`, and so on.
    ///
    /// One step of the grid is one step of whatever the arithmetic counts in -
    /// a card, a notch of a ring - so this is what makes a run settle on one
    /// of them rather than between two.
    ///
    /// - Parameters:
    ///   - value: the distance between the offsets it may rest on, in device
    ///     units. Zero rests wherever the platform leaves it.
    ///   - start: the first of them. Zero unless it says otherwise.
    /// - Returns: the reader, resting on that grid.
    public func snapInterval(_ value: Double, from start: Double = 0) -> ScrollReader {
        var copy = self
        copy.interval = value
        copy.from = start
        return copy
    }

    /// Puts the scroller itself in the author's hands, so it can be asked to
    /// move: a reader IS a scroller, and `scrollTo` is how a button moves a
    /// run without a finger.
    ///
    ///     ScrollReader(across: 540) { … }.scrollX($across).assign(scroller)
    ///
    ///     try await scroller.scrollTo(x: slot * 90, y: 0)
    ///
    /// - Parameter state: where the scroller's address is put.
    /// - Returns: the reader, whose scroller answers there.
    public func assign(_ state: ControlState<ScrollView>) -> ScrollReader {
        var copy = self
        copy.assigned = state
        return copy
    }

    /// The views, and the empty scroller lying over them.
    public var content: Element {
        let content = held
        let sideways = across
        let downward = down
        let x = reportsX
        let y = reportsY
        let step = interval
        let start = from
        let aimed = assigned

        return Grid {
            // WHAT IS BEING MOVED, taking no touches at all: everything the
            // reader does with a finger belongs to the scroller over it.
            Grid {
                content()
            }
            .inputTransparent(true)

            FrameReader { room in
                ScrollView {
                    // NOTHING TO SEE: what shows through is what lies under,
                    // and the only thing this has is a LENGTH - the room plus
                    // how far the run goes beyond it.
                    //
                    // The other side is ONE unit, never the room's own: a size
                    // taken from the room this scroller is IN is a size that
                    // feeds itself, and a measure that feeds itself does not
                    // have to settle. The scroller fills its cell either way,
                    // and takes the whole of it in touches.
                    BoxView(Color("#00000000"))
                        .widthRequest(sideways > 0 ? max(room.width, 1) + sideways : 1)
                        .heightRequest(downward > 0 ? max(room.height, 1) + downward : 1)
                }
                .orientation(
                    sideways > 0
                        ? (downward > 0 ? .both : .horizontal)
                        : .vertical)
                .horizontalScrollBarVisibility(.never)
                .verticalScrollBarVisibility(.never)
                .snapInterval(step ?? 0, from: start ?? 0)
                .reporting(x: x, y: y)
                .aimed(at: aimed)
            }
        }
    }
}

extension ScrollView {
    /// The scroller, put where an act can aim at it - and left alone where
    /// nothing asked.
    ///
    /// - Parameter state: where to put its address, if anywhere.
    /// - Returns: the scroller.
    func aimed(at state: ControlState<ScrollView>?) -> ScrollView {
        state.map { assign($0) } ?? self
    }

    /// The scroller, writing whichever of its two offsets it was given a value
    /// for.
    ///
    /// Here rather than at the call site because a modifier chain cannot leave
    /// a link out: a reader told about one axis must not write the other, and
    /// an `if` in a builder is about VIEWS rather than about the modifiers on
    /// one.
    ///
    /// - Parameters:
    ///   - x: where the offset across is written, if anywhere.
    ///   - y: where the offset down is written, if anywhere.
    /// - Returns: the scroller, reporting where it was told to.
    func reporting(x: Channel<Double>?, y: Channel<Double>?) -> ScrollView {
        var scroller = self

        if let x = x { scroller = scroller.scrollX(x) }
        if let y = y { scroller = scroller.scrollY(y) }

        return scroller
    }
}
