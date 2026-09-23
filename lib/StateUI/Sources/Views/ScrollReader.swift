// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A scroll laid over a run of views and read as a state rather than shown.
///
///     @State private var across = Point.zero
///     @State private var run = PlacedRun()
///
///     ScrollReader(across: Double(cards.count - 1) * 90) {
///         PlacedLayout(cards, id: \.name) { CardFace($0) }
///             .placement($run)
///             .engine(following: $across) { _ in
///                 run = PlacedRun(place(at: $across.journey.value.x / 90))
///             }
///     }
///     .scrollOffset($across)
///
/// What it holds is not scrolled: what moves is the offset of an empty
/// scroller lying over the views, written into a state that a layout's engine
/// follows frame by frame. A finger, a trackpad and a wheel all move it with
/// the platform's own physics, and `onScrollStopped` is where the run is
/// brought to rest on an item.
///
/// `across` and `down` are how far beyond the room it scrolls, in device
/// units: `across: 540` on a room 300 wide is a run 840 long.
public struct ScrollReader: ContentView {
    private let across: Double
    private let down: Double
    private let held: () -> [Element]

    private var reports: Binding<Point>?
    private var scroller: Aim<ScrollView>?

    /// What runs when the scroller comes to rest, if anything.
    private var stopped: EventHandler?
    private var tapped: EventHandler?

    /// Where in the room a tap is answered, given the room; nil for all of it.
    private var target: ((Rect) -> Rect)?

    /// What runs while a finger or a mouse drags the run, if anything.
    private var dragged: ValueEventHandler<PanUpdate>?

    /// The two parts of the content where a tap has a place of its own: the
    /// run's length, and where a tap may land.
    private static let parts = ["run", "tap"]

    /// Where those two stand, written on the host's own frames.
    /// Design: docs/design/views/measured-layouts.md#scroll-reader
    @State private var boxes = PlacedRun()

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

    /// Where the run is scrolled to, both ways: the user's hand writes it, and a
    /// value written here moves the scroller.
    ///
    /// - Parameter state: the state the offset is carried on.
    /// - Returns: the reader, moving with that state and reporting into it.
    public func scrollOffset(_ state: Binding<Point>) -> ScrollReader {
        var copy = self
        copy.reports = state
        return copy
    }

    /// What runs when the scroller comes to rest - the moment to carry the run
    /// on to the item it is nearest, by a write to its offset.
    ///
    ///     ScrollReader(across: 540) { … }
    ///         .scrollOffset($across)
    ///         .onScrollStopped {
    ///             across = Point(($across.journey.value.x / 90).rounded() * 90, 0)
    ///         }
    ///
    /// - Parameter handler: what to run once the scroller has stopped.
    /// - Returns: the reader, answering its scroller coming to rest.
    public func onScrollStopped(_ handler: @escaping EventHandler) -> ScrollReader {
        var copy = self
        copy.stopped = handler
        return copy
    }

    /// What runs when the user taps the run. The views under the scroller take
    /// no touches, so a tap written on one of them never fires.
    ///
    /// - Parameter handler: what to run when the run is tapped.
    /// - Returns: the reader, answering a tap.
    public func onTapped(_ handler: @escaping EventHandler) -> ScrollReader {
        var copy = self
        copy.tapped = handler
        return copy
    }

    /// What runs while the user drags the run, reported as `onPanUpdated`
    /// reports a pan - how a pointer turns a run, which no platform scrolls by
    /// dragging.
    ///
    /// - Parameter handler: what to run as the drag goes on.
    /// - Returns: the reader, answering a drag.
    public func onPanUpdated(_ handler: @escaping ValueEventHandler<PanUpdate>) -> ScrollReader {
        var copy = self
        copy.dragged = handler
        return copy
    }

    /// The same, answered on one part of the room rather than the whole run -
    /// the card in front of the user, say.
    ///
    /// The closure is handed the room and answers a rectangle in it, where the
    /// user is looking; the host keeps the box there as the run scrolls.
    /// Without `.scrollOffset($:)` the tap is answered on the whole run.
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

    /// Puts an aim on the scroller, for an act aimed at it. Moving the run is a
    /// write to the `.scrollOffset($:)` state instead:
    /// `$across.journey.snap(to:)` at once, `try await
    /// $across.journey.move(to:)` animated.
    ///
    ///     ScrollReader(across: 540) { … }.scrollOffset($across).aim(scroller)
    ///
    /// - Parameter aim: the aim the scroller answers to.
    /// - Returns: the reader, whose scroller answers there.
    public func aim(_ aim: Aim<ScrollView>) -> ScrollReader {
        var copy = self
        copy.scroller = aim
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
    public var content: any View {
        let content = held
        let sideways = across
        let downward = down
        let at = reports
        let aimed = scroller
        let rest = stopped
        let tap = tapped
        let area = target
        let drag = dragged

        return Grid {
            // What is moved takes no touches: the scroller over it takes them.
            Grid {
                content()
            }
            .ignoresInput(true)

            FrameReader { room in
                ScrollView {
                    // Nothing to see, only a length: the room plus how far the
                    // run goes beyond it. Across the axis it is one unit - or
                    // the room, where a tap must land on it - and a size worked
                    // out from the measured room does not animate.
                    // Design: docs/design/views/measured-layouts.md#scroll-reader
                    let long = sideways > 0 ? max(room.width, 1) + sideways : across(room)
                    let tall = downward > 0 ? max(room.height, 1) + downward : down(room)

                    // The box follows the state and reads where the run is.
                    let following: (any Followable)? = at
                    let reading: (() -> Point)? = at.map { held in { held.journey.value } }

                    if let area, let carried = following, let where_ = reading {
                        // A tap on one part of the room: the host keeps the box at
                        // the room's place plus how far the run has scrolled.
                        let want = area(room)
                        let along = sideways > 0

                        PlacedLayout(Self.parts, id: \.self) { part in
                            ColorBox(Color("#00000000"))
                                .motion(.none)
                                .tapping(part == Self.parts[1] ? tap : nil)
                                // Both boxes take the drag: the second lies over the first.
                                .dragging(drag)
                        }
                        .placement($boxes)
                        // The length is the layout's own size, which the scroller measures.
                        .width(long)
                        .height(tall)
                        .motion(.none, .size)
                        .engine(following: carried) { _ in
                            // Where the run is, not where it is going.
                            let stands = where_()
                            let moved = along ? stands.x : stands.y

                            // Placed at once: worked out from a measurement.
                            boxes = PlacedRun(
                                [
                                    Placement(Rect(0, 0, long, tall)),
                                    Placement(
                                        Rect(
                                            want.x + (along ? moved : 0),
                                            want.y + (along ? 0 : moved),
                                            want.width,
                                            want.height)),
                                ],
                                motion: .none)
                        }
                    } else {
                        ColorBox(Color("#00000000"))
                            .width(long)
                            .height(tall)
                            .motion(.none)
                            .tapping(tap)
                            .dragging(drag)
                    }
                }
                .orientation(
                    sideways > 0
                        ? (downward > 0 ? .both : .horizontal)
                        : .vertical)
                .horizontalScrollBarVisibility(.never)
                .verticalScrollBarVisibility(.never)
                .reporting(at: at)
                .stopping(rest)
                .aimed(at: aimed)
            }
        }
    }
}

extension ScrollView {
    /// The scroller with an aim on it, where one was asked for.
    func aimed(at aim: Aim<ScrollView>?) -> ScrollView {
        aim.map { self.aim($0) } ?? self
    }

    /// The scroller answering its own rest, where asked: an unwanted handler is
    /// an event subscribed to on every platform.
    func stopping(_ handler: EventHandler?) -> ScrollView {
        handler.map { onScrollStopped($0) } ?? self
    }

    /// The scroller carried on the offset state, where one was given: a
    /// modifier chain cannot leave a link out.
    func reporting(at: Binding<Point>?) -> ScrollView {
        at.map { self.scrollOffset($0) } ?? self
    }
}

extension ColorBox {
    /// The box answering a drag, where one was asked for.
    func dragging(_ handler: ValueEventHandler<PanUpdate>?) -> ColorBox {
        guard let handler else { return self }

        return onPanUpdated(handler)
    }

    /// The box answering a tap, where one was asked for.
    func tapping(_ handler: EventHandler?) -> ColorBox {
        handler.map { onTapped($0) } ?? self
    }
}
