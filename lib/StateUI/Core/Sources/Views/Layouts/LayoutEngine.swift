// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The centre of a layout's motion: the views, the arithmetic that places them on the host's frames, the phase it is
// worked out from, and the hand that moves the phase.
// Design: docs/design/views/layout-engine.md

/// Views placed by arithmetic of your own, worked out from a phase the user's hand or the program moves.
///
///     @State private var turn = 0.0
///
///     LayoutEngine(planets, id: \.name) { planet in
///         Ellipse(planet.colour)
///     } placements: { room, phase in
///         planets.indices.map { index in
///             let angle = (Double(index) - phase) / Double(planets.count) * 2 * .pi
///             let radius = min(room.width, room.height) / 2 - 40
///
///             return Placement(Rect(
///                 room.width / 2 + cos(angle) * radius - 24,
///                 room.height / 2 + sin(angle) * radius - 24,
///                 48,
///                 48))
///         }
///     }
///     .phase($turn)
///     .input(.scroll(.horizontal, pointsPerUnit: 90))
///     .snapTargets(planets.indices.map(Double.init))
///
/// The arithmetic runs on the host's frames whenever the room, the phase or a state named in `following(_:)` moves,
/// with no view built again. It answers one `Placement` per view, in the items' order - where the view goes from
/// the layout's top left, how it is turned, how opaque, which is drawn over which - and each lands as written:
/// what moves smoothly is the phase it is worked out from.
public struct LayoutEngine<Items: RandomAccessCollection, ID: Hashable>: View {
    // State first: boxes are adopted by path, and the views stored below may carry boxes of their own.
    // Design: docs/design/views/composition.md#state-declared-first

    /// The phase, where no binding was lent.
    @State private var ownPhase = 0.0

    /// The phase as the program last asked for it, which wakes the arithmetic where no hand moves the run.
    @State private var asked = 0.0

    /// The snap target the run last named, so a name coming back moves nothing.
    @State private var reported: Double?

    /// Where the run last stood - sent there or left there - which a change of room keeps.
    @State private var standing: Double?

    /// Whether a change of room left the scroller too short for where the run stood.
    @State private var regaining = false

    /// How long the scroller's room was along its axis when it last reported.
    @State private var measured = 0.0

    /// Where the scroller's run is laid out, as the platform reports it.
    @State private var length = Rect.zero

    /// Where the scroller is, carried both ways and never read in a body.
    @State private var scrolled = Point.zero

    /// Where the run stood along its axis when a pointer drag began.
    @State private var dragged = 0.0

    /// Where every child stands, written by the engine on the host's frames.
    @State private var placements = PlacedRun()

    /// Where the scroller's run and each view's tap box stand inside it.
    @State private var boxes = PlacedRun()

    /// The room the layout was given, as the platform reports it.
    @State private var room = Rect.zero

    /// Whether a pointer drag has to move the run: a finger drags a scroller itself, a mouse does not.
    @Environment(\.device) private var device

    /// The items, their views and the arithmetic, behind a class so the state walk stops before them.
    /// Design: docs/design/views/composition.md#items-held-behind-a-class
    private let source: Source

    /// Where the phase is written and read, when an author lent a binding.
    private var pinned: Binding<Double>?

    /// What moves the phase under the user's hand, if anything.
    private var hand: LayoutInput?

    /// Where the phase may come to rest.
    private var targets: [Double] = []

    /// States whose writes run the arithmetic again on the host's frames.
    private var followed: [(any FollowedState)?] = []

    /// What is drawn over each view at its placement's `shade`, if anything.
    private var mask: Node?

    /// What runs when the user taps a view, through its gate.
    private var tapped: (gate: any Gate, handler: ValueEventHandler<Items.Element>)?

    /// How the run travels to where the program or a settle sends it.
    private var law = Motion.inherited

    /// A layout of views, one per item, placed by `placements` on the host's frames.
    ///
    /// - Parameters:
    ///   - items: what to place, one view each.
    ///   - id: which part of an item is its identity - distinct across the items, and stable while the item means
    ///     the same view, so a view keeps its place and its state when the items change.
    ///   - content: the view for one item.
    ///   - placements: where every view goes, given the room - from the layout's top left, at its size - and the
    ///     phase as it stands this frame; one placement per view, in the items' order.
    public init<Content: View>(
        _ items: Items,
        id: KeyPath<Items.Element, ID>,
        @ViewBuilder content: @escaping (Items.Element) -> Content,
        placements: @escaping @MainActor (Rect, Double) -> [Placement]
    ) {
        source = Source(items: items, path: id, view: { content($0).node }, arithmetic: placements)
    }

    /// The same, for items that are their own identity.
    ///
    ///     LayoutEngine(["Mural", "Ridge"]) { Text($0) } placements: { room, _ in … }
    ///
    /// - Parameters:
    ///   - items: what to place, one view each.
    ///   - content: the view for one item.
    ///   - placements: where every view goes, given the room and the phase.
    public init<Content: View>(
        _ items: Items,
        @ViewBuilder content: @escaping (Items.Element) -> Content,
        placements: @escaping @MainActor (Rect, Double) -> [Placement]
    ) where Items.Element: Hashable, ID == Items.Element {
        self.init(items, id: \.self, content: content, placements: placements)
    }

    /// The phase the arithmetic is worked out from, two-way: where the run rests or is going.
    ///
    ///     @State private var turn = 0.0
    ///
    ///     LayoutEngine(cards, id: \.name) { … } placements: { … }.phase($turn)
    ///     Button("Next").onClicked { turn += 1 }
    ///
    /// Written by the program, the run travels there. Under the user's hand it is the snap target the run passes,
    /// and where it comes to rest; the arithmetic is handed the phase as it stands each frame.
    ///
    /// - Parameter state: where the phase is written and read.
    /// - Returns: the layout, worked out from that phase.
    public func phase(_ state: Binding<Double>) -> Self {
        var copy = self
        copy.pinned = state
        return copy
    }

    /// What moves the phase under the user's hand.
    ///
    ///     .input(.scroll(.horizontal, pointsPerUnit: 90))
    ///
    /// A scroll lies over the views, which take no touches of their own, and runs between the lowest and the
    /// highest snap target: it needs `snapTargets(_:)`.
    ///
    /// - Parameter input: the hand's way of moving the phase.
    /// - Returns: the layout, moved by the hand.
    public func input(_ input: LayoutInput) -> Self {
        var copy = self
        copy.hand = input
        return copy
    }

    /// Where the phase may come to rest: the hand lets go and the run travels to the nearest.
    ///
    ///     .snapTargets([0, 0.2, 0.5, 1])
    ///
    /// - Parameter targets: the phases the run may rest at.
    /// - Returns: the layout, resting on them.
    public func snapTargets(_ targets: [Double]) -> Self {
        var copy = self
        copy.targets = targets.filter(\.isFinite).sorted()
        return copy
    }

    /// States the arithmetic reads beside the room and the phase: a write to one runs it again on the host's
    /// frames, and the views land where it says.
    ///
    ///     .following($dragged)
    ///
    /// A value read in the body instead is a change of the description, the layout built again.
    ///
    /// - Parameter states: the whole states, `$x`.
    /// - Returns: the layout, following them.
    public func following<each Value>(_ states: repeat Binding<each Value>) -> Self {
        var copy = self
        for state in repeat each states { copy.followed.append(state.followed) }
        return copy
    }

    /// What to draw over a placed view to darken it, at the opacity its placement answers as `shade`.
    ///
    ///     .shade(Rectangle(.black).cornerRadius(14))
    ///
    /// Give it the corners the views have. Where views overlap, a shade darkens a far view without showing the
    /// one behind it, as fading it would.
    ///
    /// - Parameter view: what to draw over each placed view.
    /// - Returns: the layout, shaded.
    public func shade(_ view: some View) -> Self {
        var copy = self
        copy.mask = view.node
        return copy
    }

    /// How the run travels where the program or a settle sends it.
    ///
    ///     .motion(.spring(response: .milliseconds(240)))
    ///
    /// - Parameter motion: the law; the element's, the application's or the library's unless said.
    /// - Returns: the layout, travelling that way.
    public func motion(_ motion: Motion) -> Self {
        var copy = self
        copy.law = motion
        return copy
    }

    /// Runs when the user taps a view, with its item: on the view drawn on top where the tap lands.
    ///
    ///     .onItemTapped { card in open(card) }
    ///
    /// - Parameter handler: what to run, given the item.
    /// - Returns: the layout, answering a tap.
    public func onItemTapped(_ handler: @escaping @MainActor (Items.Element) throws -> Void) -> Self {
        onItemTapped(gate: .none) { try handler($0) }
    }

    /// The same, with a handler that awaits: its `gate` says what a tap does while a run is under way.
    public func onItemTapped(gate: some Gate, _ handler: @escaping ValueEventHandler<Items.Element>) -> Self {
        var copy = self
        copy.tapped = (gate, handler)
        return copy
    }

    /// The views, the hand over them and the watcher of the phase, each where the run puts it.
    public var body: some View {
        let run = self.run

        if hand != nil, targets.isEmpty {
            complain("A LayoutEngine was given a scroll but no snapTargets, which say how far it runs. Nothing scrolls.")
        }

        return PlacedStack {
            ForEach(run.slots, id: \.identity) { slot in run.wrapped(slot) }
            if run.scrolls { run.scroller() }
            Watcher(phase: run.phaseAsked, look: run.moved)
        }
        .setValue(ViewContract.area.token, on: $placements, mode: .out, kind: .placement)
        .frame($room)
        .engine([$room.followed, $asked.followed, $scrolled.followed, $length.followed] + followed,
                sync: .display, priority: 0) { _ in
            run.place()
            return .wait
        }
    }

    /// What the initializer was handed, behind a reference. See `source`.
    private final class Source {
        /// What to place, one view each.
        let items: Items

        /// Which part of an item is its identity.
        let path: KeyPath<Items.Element, ID>

        /// The view for one item, as a node.
        let view: (Items.Element) -> Node

        /// Where every view goes, given the room and the phase.
        let arithmetic: @MainActor (Rect, Double) -> [Placement]

        /// What the initializer was handed.
        init(
            items: Items,
            path: KeyPath<Items.Element, ID>,
            view: @escaping (Items.Element) -> Node,
            arithmetic: @escaping @MainActor (Rect, Double) -> [Placement]
        ) {
            self.items = items
            self.path = path
            self.view = view
            self.arithmetic = arithmetic
        }
    }

    /// What the engine and the handlers are handed: the layout as locals.
    private var run: Run {
        let items = Array(source.items)
        let path = source.path

        return Run(
            items: items,
            slots: items.enumerated().map { offset, item in
                Slot(identity: String(describing: item[keyPath: path]), index: offset, item: item)
            },
            make: source.view,
            arithmetic: source.arithmetic,
            mask: mask,
            tapped: tapped,
            pinned: pinned,
            states: States(
                ownPhase: _ownPhase, asked: _asked, reported: _reported, standing: _standing, regaining: _regaining,
                measured: _measured, length: _length, scrolled: _scrolled, dragged: _dragged,
                placements: _placements, boxes: _boxes, room: _room),
            targets: targets,
            law: law,
            scrolls: hand != nil && !targets.isEmpty,
            across: hand?.axis != .vertical,
            per: hand?.pointsPerUnit ?? 1,
            drags: hand != nil && !targets.isEmpty && device.info.formFactor == .desktop)
    }

    /// The layout's states, handed on whole: what its engine and handlers read and write.
    struct States {
        let ownPhase: State<Double>
        let asked: State<Double>
        let reported: State<Double?>
        let standing: State<Double?>
        let regaining: State<Bool>
        let measured: State<Double>
        let length: State<Rect>
        let scrolled: State<Point>
        let dragged: State<Double>
        let placements: State<PlacedRun>
        let boxes: State<PlacedRun>
        let room: State<Rect>
    }
}

/// The phase's watcher: a view of nothing that reads the phase asked for, so the read rebuilds it and not the layout.
/// Design: docs/design/views/composition.md#a-watcher-is-a-view-of-its-own
private struct Watcher: View {
    /// The phase asked for - ASKED here, so the read is this view's.
    let phase: () -> Double

    /// What a new phase means.
    let look: (Double) -> Void

    var body: some View {
        let asked = phase()

        return Rectangle(.transparent)
            .width(0)
            .height(0)
            .ignoresInput(true)
            .onChanged(asked) { look(asked) }
    }
}
