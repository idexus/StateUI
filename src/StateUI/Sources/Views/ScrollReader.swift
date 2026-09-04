// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A scroll laid OVER a run of views, read as a driven state rather than shown.
/// This library's own.
///
///     @State(describing: .none) private var across = 0.0
///
///     @State(describing: .none) private var run = PlacedRun()
///
///     ScrollReader(across: Double(cards.count - 1) * 90) {
///         PlacedLayout(cards, id: \.name) { CardFace($0) }
///             .placement($run)
///             .engine(following: $across) { _ in
///                 run = PlacedRun(place(at: across / 90))
///             }
///     }
///     .scrollX($across)
///     .snapInterval(90)
///
/// What it holds is not scrolled: the views stay where their own arithmetic
/// puts them, and what moves is a NUMBER - the offset of an empty scroller
/// lying over them, written into a driven state. A layout following that state
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

    private var reportsX: Binding<Double>?
    private var reportsY: Binding<Double>?
    private var interval: Double?
    private var from: Double?
    private var assigned: ControlState<ScrollView>?
    private var nearest: Binding<Int>?
    private var limit = 0

    /// How much of the platform's own throw a release keeps. Nothing said
    /// leaves the platform's physics alone.
    private var carry: Double?
    private var tapped: EventHandler?

    /// Where in the ROOM a tap is answered, given the room - or nothing, which
    /// means the whole of it.
    private var target: ((Rect) -> Rect)?

    /// The two things the content is made of when a tap has a place of its
    /// own: how long the run is, and where the finger may land. Named rather
    /// than numbered so neither can be mistaken for a view of the author's.
    private static let parts = ["run", "tap"]

    /// Where those two stand, written on the host's own frames. The box that
    /// answers the tap follows the offset, and an offset moves far too often
    /// to describe - see `onTapped(within:)`.
    @State(describing: .none) private var boxes = PlacedRun()

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
    /// - Parameter value: the driven state it is written into.
    /// - Returns: the reader, reporting there.
    public func scrollX(_ value: Binding<Double>) -> ScrollReader {
        var copy = self
        copy.reportsX = value
        return copy
    }

    /// Where the offset DOWN is written.
    ///
    /// - Parameter value: the driven state it is written into.
    /// - Returns: the reader, reporting there.
    public func scrollY(_ value: Binding<Double>) -> ScrollReader {
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

    /// Which point of the GRID the run is nearest, written as it moves.
    ///
    /// The number is the platform's own rounding - the same one that chose
    /// where the movement would land - so it names the point while the run is
    /// still crossing to it and cannot disagree with where it ends. Beside
    /// `snapInterval(_:from:)`, which is what makes there be a grid to be
    /// nearest a point of.
    ///
    ///     ScrollReader(across: 540) { … }
    ///         .scrollX($across)
    ///         .snapInterval(90)
    ///         .snapItem($card)
    ///
    /// - Parameter binding: where the nearest point of the grid is written.
    /// - Returns: the reader, naming it.
    public func snapItem(_ binding: Binding<Int>) -> ScrollReader {
        var copy = self
        copy.nearest = binding
        return copy
    }

    /// The most points of the grid one release may cross. Nothing is the
    /// default, and means as many as the throw carries.
    /// `ScrollView.snapsAtMost(_:)`.
    ///
    /// - Parameter points: how many points a release may cross. Zero is no
    ///   limit.
    /// - Returns: the reader, holding a release to that many.
    public func snapsAtMost(_ points: Int) -> ScrollReader {
        var copy = self
        copy.limit = max(0, points)
        return copy
    }

    /// How far a released scroll CARRIES, as a fraction of what the platform
    /// would do on its own. The platform's own throw is the default.
    /// `ScrollView.momentum(_:)`.
    ///
    /// - Parameter fraction: how much of the platform's throw to keep.
    /// - Returns: the reader, throwing that far.
    public func momentum(_ fraction: Double) -> ScrollReader {
        var copy = self
        copy.carry = max(0, fraction)
        return copy
    }

    /// What runs when the reader TAPS the run.
    ///
    /// It lands inside the scroller, which is what lies over the views and the
    /// only thing here a finger can reach: what the reader holds takes no
    /// touches at all, so a tap written on one of those views would never fire.
    ///
    /// - Parameter handler: what to run when the run is tapped.
    /// - Returns: the reader, answering a tap.
    public func onTapped(_ handler: @escaping EventHandler) -> ScrollReader {
        var copy = self
        copy.tapped = handler
        return copy
    }

    /// The same, answered on ONE PART of the room rather than on the whole run.
    ///
    /// The closure is handed the room and answers a rectangle IN IT - where the
    /// reader is looking, not where the run has been scrolled to. The box is
    /// KEPT there: it lies in the content, which slides under the room, so the
    /// host carries it by the same offset the scroller reports, on its own
    /// frames and without a word to the tree. A run of cards is why this
    /// exists: what a tap means is the card in front of the reader, and a tap
    /// on the empty run beside it means nothing.
    ///
    /// It needs a driven state to be carried by, so a reader that reports neither
    /// offset answers the tap on the whole of the run, as `onTapped` does.
    ///
    /// - Parameters:
    ///   - area: where in the room the tap is answered, given the room.
    ///   - handler: what to run when that part of the room is tapped.
    /// - Returns: the reader, answering a tap there and nowhere else.
    public func onTapped(
        within area: @escaping (Rect) -> Rect,
        _ handler: @escaping EventHandler
    ) -> ScrollReader {
        var copy = self
        copy.tapped = handler
        copy.target = area
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

    /// How wide the scroller's content is where the run does not go sideways:
    /// nothing to speak of, or the room where a tap has to land on it.
    private func across(_ room: Rect) -> Double {
        tapped == nil ? 1 : max(room.width, 1)
    }

    /// And how tall it is where the run does not go down.
    private func down(_ room: Rect) -> Double {
        tapped == nil ? 1 : max(room.height, 1)
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
        let slot = nearest
        let most = limit
        let thrown = carry
        let tap = tapped
        let area = target

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
                    // Across the axis it is ONE unit, never the room's own: a
                    // size taken from the room this scroller is IN is a size
                    // that feeds itself, and a measure that feeds itself does
                    // not have to settle. The scroller fills its cell either
                    // way, and takes the whole of it in touches.
                    //
                    // UNLESS A TAP WAS ASKED FOR, and then it is the room: a
                    // tap has to land on something, and the scroller is not
                    // that something - measured on Android, where a run swiped
                    // at a point answered no tap at the same point. One unit of
                    // content is one unit of target. The room is the CELL this
                    // scroller was given, so a content as tall as it asks for
                    // no more room than there already is.
                    // A SIZE WORKED OUT FROM A MEASUREMENT DOES NOT
                    // TRAVEL: the length is arithmetic over the measured
                    // room, so carried by the default motion it would crawl
                    // after every change of it - and each step of a walked
                    // size is a measure pass of the whole page, which starves
                    // the frame clock every other motion runs on.
                    let long = sideways > 0 ? max(room.width, 1) + sideways : across(room)
                    let tall = downward > 0 ? max(room.height, 1) + downward : down(room)

                    if let area, let carried = x ?? y {
                        // A TAP ON ONE PART OF THE ROOM, and the host is what
                        // keeps it there. The box lies in the CONTENT, which
                        // slides under the room, so where it belongs is the
                        // room's own place plus however far the run has been
                        // scrolled - a number that moves on the platform's own
                        // frames and is never described. Read from the slot
                        // instead, it would be right at rest and wrong for
                        // every offset the run settles at that the tree has
                        // not heard about.
                        //
                        // The first box is the LENGTH and takes no touches; it
                        // is also what makes the second one reachable, a view
                        // outside its parent's bounds being drawn and not
                        // touched.
                        let want = area(room)
                        let along = sideways > 0

                        PlacedLayout(Self.parts, id: \.self) { part in
                            BoxView(Color("#00000000"))
                                .motion(.none)
                                .tapping(part == Self.parts[1] ? tap : nil)
                        }
                        .placement($boxes)
                        .engine(following: carried) { _ in
                            let moved = carried.wrappedValue

                            boxes = PlacedRun([
                                Placement(Rect(0, 0, long, tall)),
                                Placement(
                                    Rect(
                                        want.x + (along ? moved : 0),
                                        want.y + (along ? 0 : moved),
                                        want.width,
                                        want.height)),
                            ])
                        }
                    } else {
                        BoxView(Color("#00000000"))
                            .widthRequest(long)
                            .heightRequest(tall)
                            .motion(.none)
                            .tapping(tap)
                    }
                }
                .orientation(
                    sideways > 0
                        ? (downward > 0 ? .both : .horizontal)
                        : .vertical)
                .horizontalScrollBarVisibility(.never)
                .verticalScrollBarVisibility(.never)
                .snapInterval(step ?? 0, from: start ?? 0)
                .throwing(thrown)
                .holding(most)
                .reporting(x: x, y: y)
                .naming(slot)
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

    /// The scroller, keeping that much of the platform's own throw - and left
    /// alone where nothing asked, there being no fraction that means "all of
    /// it and do not say so".
    ///
    /// - Parameter fraction: how much to keep, if anything was said.
    /// - Returns: the scroller.
    func throwing(_ fraction: Double?) -> ScrollView {
        fraction.map { momentum($0) } ?? self
    }

    /// The scroller, holding one release to that many points of the grid - and
    /// left alone where nothing asked, nought being the absence of a limit
    /// rather than a limit of nought.
    ///
    /// - Parameter points: the limit, if any.
    /// - Returns: the scroller.
    func holding(_ points: Int) -> ScrollView {
        points > 0 ? snapsAtMost(points) : self
    }

    /// The scroller, naming the point of the grid it is nearest - and left
    /// alone where nothing asked.
    ///
    /// - Parameter binding: where to write it, if anywhere.
    /// - Returns: the scroller.
    func naming(_ binding: Binding<Int>?) -> ScrollView {
        binding.map { snapItem($0) } ?? self
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
    func reporting(x: Binding<Double>?, y: Binding<Double>?) -> ScrollView {
        var scroller = self

        if let x = x { scroller = scroller.scrollX(x) }
        if let y = y { scroller = scroller.scrollY(y) }

        return scroller
    }
}

extension BoxView {
    /// The view, answering a tap - and left alone where nothing asked, an
    /// unwanted handler being an event subscribed to on every platform.
    ///
    /// - Parameter handler: what to run when it is tapped, if anything.
    /// - Returns: the view.
    func tapping(_ handler: EventHandler?) -> BoxView {
        handler.map { onTapped($0) } ?? self
    }
}
