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
public struct ScrollReader: View {
    private let across: Double
    private let down: Double
    private let held: () -> [Node]

    private var reports: Binding<Point>?
    private var scroller: Aim<ScrollView>?

    /// What runs when the scroller comes to rest, if anything.
    private var stopped: (gate: any Gate, handler: EventHandler)?
    private var tapped: (gate: any Gate, handler: EventHandler)?

    /// Where in the room a tap is answered, given the room; nil for all of it.
    private var target: ((Rect) -> Rect)?

    /// What runs while a finger or a mouse drags the run, if anything.
    private var dragged: (gate: any Gate, handler: ValueEventHandler<PanUpdate>)?

    /// Where the scroller's run is laid out, as the platform reports it, where a reader in this module asked.
    private var laid: Binding<Rect>?

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
    public init<Content: Views>(across: Double, @ViewBuilder content: @escaping () -> Content) {
        self.init(across: across, down: 0, content: content)
    }

    /// A run that scrolls DOWN.
    ///
    /// - Parameters:
    ///   - down: how far beyond the room it can be scrolled, in device units.
    ///   - content: the views lying under it.
    public init<Content: Views>(down: Double, @ViewBuilder content: @escaping () -> Content) {
        self.init(across: 0, down: down, content: content)
    }

    /// A run that scrolls both ways.
    ///
    /// - Parameters:
    ///   - across: how far beyond the room it can be scrolled sideways, in
    ///     device units.
    ///   - down: how far beyond the room it can be scrolled, in device units.
    ///   - content: the views lying under it.
    public init<Content: Views>(
        across: Double,
        down: Double,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.across = across
        self.down = down
        self.held = { content().nodes }
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
    public func onScrollStopped(_ handler: @escaping @MainActor () throws -> Void) -> ScrollReader {
        onScrollStopped(gate: .none) { try handler() }
    }

    /// The same, with a handler that awaits: its `gate` says what the scroller coming to rest does while a run
    /// is under way.
    public func onScrollStopped(gate: some Gate, _ handler: @escaping EventHandler) -> ScrollReader {
        var copy = self
        copy.stopped = (gate, handler)
        return copy
    }

    /// A handler that awaits passes through a gate.
    @available(*, unavailable, message: "a handler that awaits passes through a gate: .onScrollStopped(gate: saving) { … } with @State var saving = SharedGate(.ignoreWhileRunning) - or gate: .none")
    public func onScrollStopped(_ handler: @escaping EventHandler) -> ScrollReader {
        fatalError("unavailable")
    }

    /// What runs when the user taps the run. The views under the scroller take
    /// no touches, so a tap written on one of them never fires.
    ///
    /// - Parameter handler: what to run when the run is tapped.
    /// - Returns: the reader, answering a tap.
    public func onTapped(_ handler: @escaping @MainActor () throws -> Void) -> ScrollReader {
        onTapped(gate: .none) { try handler() }
    }

    /// The same, with a handler that awaits: its `gate` says what a tap does while a run is under way.
    public func onTapped(gate: some Gate, _ handler: @escaping EventHandler) -> ScrollReader {
        var copy = self
        copy.tapped = (gate, handler)
        return copy
    }

    /// A handler that awaits passes through a gate.
    @available(*, unavailable, message: "a handler that awaits passes through a gate: .onTapped(gate: saving) { … } with @State var saving = SharedGate(.ignoreWhileRunning) - or gate: .none")
    public func onTapped(_ handler: @escaping EventHandler) -> ScrollReader {
        fatalError("unavailable")
    }

    /// What runs while the user drags the run, reported as `onPanUpdated`
    /// reports a pan - how a pointer turns a run, which no platform scrolls by
    /// dragging.
    ///
    /// - Parameter handler: what to run as the drag goes on.
    /// - Returns: the reader, answering a drag.
    public func onPanUpdated(_ handler: @escaping @MainActor (PanUpdate) throws -> Void) -> ScrollReader {
        onPanUpdated(gate: .none) { try handler($0) }
    }

    /// The same, with a handler that awaits: its `gate` says what a report of the drag does while a run is
    /// under way.
    public func onPanUpdated(
        gate: some Gate, _ handler: @escaping ValueEventHandler<PanUpdate>
    ) -> ScrollReader {
        var copy = self
        copy.dragged = (gate, handler)
        return copy
    }

    /// A handler that awaits passes through a gate.
    @available(*, unavailable, message: "a handler that awaits passes through a gate: .onPanUpdated(gate: saving) { … } with @State var saving = SharedGate(.ignoreWhileRunning) - or gate: .none")
    public func onPanUpdated(_ handler: @escaping ValueEventHandler<PanUpdate>) -> ScrollReader {
        fatalError("unavailable")
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
        _ handler: @escaping @MainActor () throws -> Void
    ) -> ScrollReader {
        onTapped(within: area, gate: .none) { try handler() }
    }

    /// The same, with a handler that awaits: its `gate` says what a tap does while a run is under way.
    public func onTapped(
        within area: @escaping (Rect) -> Rect,
        gate: some Gate,
        _ handler: @escaping EventHandler
    ) -> ScrollReader {
        var copy = self
        copy.tapped = (gate, handler)
        copy.target = area
        return copy
    }

    /// A handler that awaits passes through a gate.
    @available(*, unavailable, message: "a handler that awaits passes through a gate: .onTapped(within: area, gate: saving) { … } with @State var saving = SharedGate(.ignoreWhileRunning) - or gate: .none")
    public func onTapped(within area: @escaping (Rect) -> Rect, _ handler: @escaping EventHandler) -> ScrollReader {
        fatalError("unavailable")
    }

    /// Puts an aim on the scroller, for an act aimed at it. Moving the run is a
    /// write to the `.scrollOffset($:)` state instead:
    /// `$across.journey.snap(to:)` at once, `$across.journey.move(to:)`
    /// animated.
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

    /// The run laid out, reported onto `state`: the room the run is as long as is measured a render after it
    /// changed, so a reader learns here when the scroller can hold what the new room asks.
    /// Design: docs/design/views/measured-layouts.md#scroll-reader
    func laidOut(_ state: Binding<Rect>) -> ScrollReader {
        var copy = self
        copy.laid = state
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
    public var body: some View {
        let content = held
        let sideways = across
        let downward = down
        let at = reports
        let aimed = scroller
        let rest = stopped
        let tap = tapped
        let area = target
        let drag = dragged
        let length = laid

        return Grid {
            // What is moved takes no touches: the scroller over it takes them.
            Grid { BuiltViews(nodes: content()) }
                .ignoresInput(true)

            GeometryReader { room in
                ScrollView {
                    // Nothing to see, only a length: the room plus how far the
                    // run goes beyond it. Across the axis it is one unit - or
                    // the room, where a tap must land on it - and a size worked
                    // out from the measured room does not animate.
                    // Design: docs/design/views/measured-layouts.md#scroll-reader
                    let long = sideways > 0 ? max(room.width, 1) + sideways : across(room)
                    let tall = downward > 0 ? max(room.height, 1) + downward : down(room)

                    // The box follows the state and reads where the run is.
                    let reading: (() -> Point)? = at.map { held in { held.journey.value } }

                    if let area, let carried = at, let where_ = reading {
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
                        .reporting(laid: length)
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
                            .reporting(laid: length)
                    }
                }
                .orientation(
                    sideways > 0
                        ? (downward > 0 ? .both : .horizontal)
                        : .vertical)
                .horizontalScrollIndicator(.never)
                .verticalScrollIndicator(.never)
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
    func stopping(_ handler: (gate: any Gate, handler: EventHandler)?) -> ScrollView {
        guard let handler else { return self }

        return onScrollStopped(gate: handler.gate, handler.handler)
    }

    /// The scroller carried on the offset state, where one was given: a
    /// modifier chain cannot leave a link out.
    func reporting(at: Binding<Point>?) -> ScrollView {
        at.map { self.scrollOffset($0) } ?? self
    }
}

extension VisualElement where Modified == Self {
    /// The element reporting where it is laid out onto `state`, where one was given.
    func reporting(laid state: Binding<Rect>?) -> Self {
        state.map { frame($0) } ?? self
    }
}

extension ColorBox {
    /// The box answering a drag, where one was asked for.
    func dragging(_ handler: (gate: any Gate, handler: ValueEventHandler<PanUpdate>)?) -> ColorBox {
        guard let handler else { return self }

        return onPanUpdated(gate: handler.gate, handler.handler)
    }

    /// The box answering a tap, where one was asked for.
    func tapping(_ handler: (gate: any Gate, handler: EventHandler)?) -> ColorBox {
        guard let handler else { return self }

        return onTapped(gate: handler.gate, handler.handler)
    }
}
