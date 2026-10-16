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
///     .input(.scroll(.horizontal))
///     .snapTargets(planets.indices.map(Double.init))
///
/// The arithmetic runs on the host's frames whenever the room, the phase or a state named in `following(_:)` moves,
/// with no view built again. It answers one `Placement` per view, in the items' order - where the view goes from
/// the layout's top left, how it is turned, how opaque, which is drawn over which - and each lands as written:
/// what moves smoothly is the phase it is worked out from. A phase of several axes is a `LayoutPhase` of your own,
/// each axis moved by its own hand or by the program.
public struct LayoutEngine<Items: RandomAccessCollection, ID: Hashable, Phase: LayoutPhase>: View {
    // State first: boxes are adopted by path, and the views stored below may carry boxes of their own.
    // Design: docs/design/views/composition.md#state-declared-first

    /// The phase, where no binding was lent.
    @State private var ownPhase = Phase()

    /// Where the hand holds the run on its axis, while it does: what the arithmetic is handed then, the phase
    /// itself named only as the hand passes a target.
    @State private var held: Double?

    /// The hand's throw going on after it let go, on the hand's axis, where one does.
    @State private var flung: LayoutFling?

    /// Where a swiping hand took the run, and the unit it moves it by, while it holds it.
    @State private var grip: LayoutGrip?

    /// Where every child stands, written by the engine on the host's frames.
    @State private var placements = PlacedRun()

    /// What the run last showed and the changes on their way to its poses.
    @State private var shown = LayoutShown<Phase>()

    /// The phase the run stood at when its motion set out, kept until it rests again.
    @State private var from: Phase?

    /// The room the layout was given, as the platform reports it.
    @State private var room = Rect.zero

    /// The items, their views and the arithmetic, behind a class so the state walk stops before them.
    /// Design: docs/design/views/composition.md#items-held-behind-a-class
    private let source: Source

    /// Where the phase is written and read, when an author lent a binding.
    private var pinned: Binding<Phase>?

    /// What moves the phase under the user's hand, if anything, and the axis it moves.
    private var hand: (input: LayoutInput, axis: WritableKeyPath<Phase, Double>)?

    /// The whole phases the run may come to rest at.
    private var targets: [Phase] = []

    /// The axes that rest on targets of their own, each on its own.
    private var axisTargets: [WritableKeyPath<Phase, Double>: [Double]] = [:]

    /// The axes that come round again, by how far one turn takes them.
    private var periods: [WritableKeyPath<Phase, Double>: Double] = [:]

    /// States whose writes run the arithmetic again on the host's frames.
    private var followed: [(any FollowedState)?] = []

    /// What is drawn over each view at its placement's `shade`, if anything.
    private var mask: Node?

    /// What runs when the user taps a view, through its gate.
    private var tapped: ValueHandler<Items.Element>?

    /// How the run travels to where the program or the hand's throw sends it.
    private var law = Motion.inherited

    /// What a target the run names is told to beside the phase: a composed control's own value worked out from it.
    private var named: ((Phase) -> Void)?

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
        placements: @escaping @MainActor (Rect, Phase) -> [Placement]
    ) {
        self.init(items, id: id, content: content, placements: { room, phase, _ in placements(room, phase) })
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
        placements: @escaping @MainActor (Rect, Phase) -> [Placement]
    ) where Items.Element: Hashable, ID == Items.Element {
        self.init(items, id: \.self, content: content, placements: placements)
    }

    /// A layout whose arithmetic is handed, beside the phase, where the run's motion set out: the phase it stood
    /// at when the hand, a throw or a journey took it away, then each target the run passes on the hand's axis.
    ///
    ///     LayoutEngine(cards, id: \.name) { card in Face(card) } placements: { room, phase, from in
    ///         // The card that stood in front leaves the way the run goes - phase above `from` or below it.
    ///     }
    ///
    /// The way the run goes is the phase's side of `from`; back past it, the run goes the other way from the same
    /// place, and at `from` itself every view stands where it stood, so nothing drawn from it jumps.
    ///
    /// - Parameters:
    ///   - items: what to place, one view each.
    ///   - id: which part of an item is its identity.
    ///   - content: the view for one item.
    ///   - placements: where every view goes, given the room, the phase as it stands this frame and the phase the
    ///     run's motion set out from; one placement per view, in the items' order.
    public init<Content: View>(
        _ items: Items,
        id: KeyPath<Items.Element, ID>,
        @ViewBuilder content: @escaping (Items.Element) -> Content,
        placements: @escaping @MainActor (Rect, Phase, Phase) -> [Placement]
    ) {
        source = Source(items: items, path: id, view: { content($0).node }, arithmetic: placements)
    }

    /// The same, for items that are their own identity.
    public init<Content: View>(
        _ items: Items,
        @ViewBuilder content: @escaping (Items.Element) -> Content,
        placements: @escaping @MainActor (Rect, Phase, Phase) -> [Placement]
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
    public func phase(_ state: Binding<Phase>) -> Self {
        var copy = self
        copy.pinned = state
        return copy
    }

    /// What moves one axis of the phase under the user's hand.
    ///
    ///     .input(.scroll(.horizontal, pointsPerUnit: 240), drives: \.turn)
    ///
    /// The hand moves the axis as it moves, between the lowest and the highest snap target on it - or round and
    /// round where the axis `wraps(_:every:)` - and let go, the run goes on to the target nearest where its throw
    /// would end: it needs `snap(_:to:)` for that axis or `snapTargets(_:)`. The hand moves its own axis alone;
    /// the others go on as the program sends them. The views still answer a tap.
    ///
    /// - Parameters:
    ///   - input: the hand's way of moving the axis.
    ///   - axis: the axis it moves.
    /// - Returns: the layout, moved by the hand.
    public func input(_ input: LayoutInput, drives axis: WritableKeyPath<Phase, Double>) -> Self {
        var copy = self
        copy.hand = (input, axis)
        return copy
    }

    /// The whole phases the run may come to rest at: the hand lets go and the run travels to the nearest.
    ///
    ///     .snapTargets([0, 0.2, 0.5, 1])
    ///     .snapTargets([Orbit(turn: 0, zoom: 1), Orbit(turn: 1, zoom: 2)])
    ///
    /// Of a phase of several axes they are the combinations allowed: the nearest is the one at the least distance
    /// over the axes given no targets of their own by `snap(_:to:)`, and every one of those axes travels to it.
    ///
    /// - Parameter targets: the phases the run may rest at.
    /// - Returns: the layout, resting on them.
    public func snapTargets(_ targets: [Phase]) -> Self {
        var copy = self
        copy.targets = targets.filter { target in Phase.axes.allSatisfy { target[keyPath: $0].isFinite } }
        return copy
    }

    /// The same axis, round and round: one turn of `period` brings the layout back to where it was, so the hand
    /// moves it on for ever and its snap targets come round again every period.
    ///
    ///     .snap(\.turn, to: cards.indices.map(Double.init))
    ///     .wraps(\.turn, every: Double(cards.count))
    ///
    /// The axis has no end: past the last card it is the first again, a turn on - `turn` 9 of seven cards is the
    /// third - so a write of one more always travels one card on.
    ///
    /// - Parameters:
    ///   - axis: the axis.
    ///   - period: how far one turn takes it; above nought.
    /// - Returns: the layout, its axis coming round.
    public func wraps(_ axis: WritableKeyPath<Phase, Double>, every period: Double) -> Self {
        var copy = self
        copy.periods[axis] = period.isFinite && period > 0 ? period : nil
        return copy
    }

    /// Where one axis of the phase may come to rest, whatever the other axes do.
    ///
    ///     .snap(\.turn, to: cards.indices.map(Double.init))
    ///     .snap(\.zoom, to: [1, 2])
    ///
    /// The axis rests on its own targets alone, and only its own hand moves it there.
    ///
    /// - Parameters:
    ///   - axis: the axis.
    ///   - targets: where it may rest.
    /// - Returns: the layout, resting that axis on them.
    public func snap(_ axis: WritableKeyPath<Phase, Double>, to targets: [Double]) -> Self {
        var copy = self
        copy.axisTargets[axis] = targets.filter(\.isFinite).sorted()
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

    /// How the run travels where the program or a settle sends it; let go short of the next target, the run comes
    /// onto it at a unit a length of this motion, so the short way is short.
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
        var copy = self
        copy.tapped = ValueHandler(step: handler)
        return copy
    }

    /// The same, with a handler that awaits: its `gate` says what a tap does while a run is under way.
    public func onItemTapped(gate: some Gate, _ handler: @escaping ValueEventHandler<Items.Element>) -> Self {
        var copy = self
        copy.tapped = ValueHandler(run: handler, gate: gate)
        return copy
    }

    /// The same layout telling `handler` each target the run names, as it names it: what a composed control
    /// keeps a value of its own by - `GalleryView`'s position.
    func onNamed(_ handler: @escaping (Phase) -> Void) -> Self {
        var copy = self
        copy.named = handler
        return copy
    }

    /// The views and the hand over them, each where the run puts it.
    public var body: some View {
        let run = self.run

        if Phase.axes.isEmpty {
            complain("A LayoutEngine's phase names no axes: `axes` lists the numbers the hand and the program move.")
        }
        if hand != nil, run.stops.isEmpty {
            complain("A LayoutEngine was given a scroll but no snap targets on the axis it drives, which say how far "
                + "it runs and where it rests. The hand moves nothing.")
        }
        if let pinned, pinned.followed == nil {
            complain("A LayoutEngine's phase is a state lent with `$`: a binding worked out from others cannot be "
                + "worn, so the phase would jump where it is sent rather than travel there.")
        }

        return PlacedStack {
            ForEach(run.slots, id: \.identity) { slot in run.wrapped(slot) }
        }
        .modified { element in
            // The hand is heard on the element itself, over every view, which still answers a tap.
            element.describe(LayoutEngineContract.handAxis, run.moves ? (run.across ? .horizontal : .vertical) : nil)
            if run.moves {
                element.addHandler(LayoutEngineContract.handMoved) { phase, moved, speed in
                    run.hand(phase, moved: moved, speed: speed)
                }
                element.addHandler(LayoutEngineContract.handStepped) { notches in run.step(notches) }
            }
        }
        .setValue(ViewContract.area.token, on: $placements, mode: .out, kind: .placement)
        .setValue(LayoutEngineContract.phase.token, on: run.phase, mode: .inOut, kind: .property)
        .motion(law)
        .frame($room)
        .engine([$room.followed, run.phase.followed, $held.followed, $flung.followed] + followed,
                sync: .display, priority: 0) { cycle in
            run.place(at: cycle.now, reducesMotion: cycle.reducesMotion)
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

        /// Where every view goes, given the room, the phase and where its motion set out.
        let arithmetic: @MainActor (Rect, Phase, Phase) -> [Placement]

        /// Which description this is: the next number at each, never one again - an object's address is, once it
        /// is let go.
        let number: Int

        /// What the initializer was handed.
        @MainActor
        init(
            items: Items,
            path: KeyPath<Items.Element, ID>,
            view: @escaping (Items.Element) -> Node,
            arithmetic: @escaping @MainActor (Rect, Phase, Phase) -> [Placement]
        ) {
            self.items = items
            self.path = path
            self.view = view
            self.arithmetic = arithmetic
            descriptionsMade += 1
            number = descriptionsMade
        }
    }

    /// What the engine and the handlers are handed: the layout as locals.
    private var run: Run {
        let items = Array(source.items)
        let path = source.path
        let axis = hand?.axis
        let stops = axis.map { axis in axisTargets[axis] ?? Set(targets.map { $0[keyPath: axis] }).sorted() } ?? []

        return Run(
            items: items,
            slots: items.enumerated().map { offset, item in
                Slot(identity: String(describing: item[keyPath: path]), index: offset, item: item)
            },
            make: source.view,
            arithmetic: source.arithmetic,
            description: source.number,
            mask: mask,
            tapped: tapped,
            named: named,
            phase: pinned ?? $ownPhase,
            states: States(
                held: _held, flung: _flung, placements: _placements, room: _room, shown: _shown, from: _from,
                grip: _grip),
            axis: axis,
            stops: stops,
            period: axis.flatMap { periods[$0] },
            targets: targets,
            axisTargets: axisTargets,
            law: law,
            moves: hand != nil && !stops.isEmpty,
            across: hand?.input.axis != .vertical,
            travel: hand?.input.travel ?? .front,
            swipes: hand?.input.swipes ?? false,
            throwing: hand?.input.throwing ?? LayoutInput.scroll(.horizontal).throwing)
    }

    /// The layout's states, handed on whole: what its engine and handlers read and write.
    struct States {
        let held: State<Double?>
        let flung: State<LayoutFling?>
        let placements: State<PlacedRun>
        let room: State<Rect>
        let shown: State<LayoutShown<Phase>>
        let from: State<Phase?>
        let grip: State<LayoutGrip?>
    }
}

extension LayoutEngine where Phase == Double {
    /// The same, with a phase of one axis: a `Double`.
    public init<Content: View>(
        _ items: Items,
        id: KeyPath<Items.Element, ID>,
        @ViewBuilder content: @escaping (Items.Element) -> Content,
        placements: @escaping @MainActor (Rect, Double) -> [Placement]
    ) {
        self.init(items, id: id, content: content, placements: { room, phase, _ in placements(room, phase) })
    }

    /// The same, for items that are their own identity, with a phase of one axis.
    public init<Content: View>(
        _ items: Items,
        @ViewBuilder content: @escaping (Items.Element) -> Content,
        placements: @escaping @MainActor (Rect, Double) -> [Placement]
    ) where Items.Element: Hashable, ID == Items.Element {
        self.init(items, id: \.self, content: content, placements: placements)
    }

    /// The same, with a phase of one axis and where the run's motion set out on it.
    public init<Content: View>(
        _ items: Items,
        id: KeyPath<Items.Element, ID>,
        @ViewBuilder content: @escaping (Items.Element) -> Content,
        placements: @escaping @MainActor (Rect, Double, Double) -> [Placement]
    ) {
        source = Source(items: items, path: id, view: { content($0).node }, arithmetic: placements)
    }

    /// The same, for items that are their own identity, with a phase of one axis and where its motion set out.
    public init<Content: View>(
        _ items: Items,
        @ViewBuilder content: @escaping (Items.Element) -> Content,
        placements: @escaping @MainActor (Rect, Double, Double) -> [Placement]
    ) where Items.Element: Hashable, ID == Items.Element {
        self.init(items, id: \.self, content: content, placements: placements)
    }

    /// What moves the phase under the user's hand.
    ///
    ///     .input(.scroll(.horizontal))
    ///
    /// The hand moves the phase between the lowest and the highest snap target - round and round where it
    /// `wraps(every:)` - and let go, the run goes on to the target nearest where its throw would end: it needs
    /// `snapTargets(_:)`.
    ///
    /// - Parameter input: the hand's way of moving the phase.
    /// - Returns: the layout, moved by the hand.
    public func input(_ input: LayoutInput) -> Self {
        self.input(input, drives: \.self)
    }

    /// The phase, round and round: one turn of `period` brings the layout back to where it was.
    ///
    ///     .wraps(every: Double(cards.count))
    ///
    /// - Parameter period: how far one turn takes the phase; above nought.
    /// - Returns: the layout, coming round.
    public func wraps(every period: Double) -> Self {
        wraps(\.self, every: period)
    }
}

/// How many descriptions of layout engines have been made.
@MainActor private var descriptionsMade = 0

/// A throw of the hand going on after it let go, on the hand's axis: from where it let go, to the target nearest
/// where it would end, setting out at the hand's speed, units a second; when it set out, once a frame says.
struct LayoutFling: Equatable {
    let from: Double
    let to: Double
    let speed: Double

    /// The motion it goes on under, how long it takes where that motion is eased, in milliseconds, and whether it is
    /// a throw - the hand's own motion going on - or an approach, which less motion lands at once.
    let motion: Motion
    let flight: Double
    let thrown: Bool
    var began: Double?
}

/// Where a swiping hand took the run - the target nearest, one either side of which it moves it - and the unit it
/// moves it by, measured there; nil for none the hand can measure.
struct LayoutGrip: Equatable {
    let target: Double
    let unit: Double?
}

/// What a layout last showed - the description it came from, at what phase, set out from where and in what room,
/// each view's pose and where it was shown, by identity - and the changes on their way to the poses: what a new
/// description is measured against.
struct LayoutShown<Phase: LayoutPhase>: Equatable {
    var description: Int?
    var phase: Phase?
    var from: Phase?
    var room = Rect.zero
    var poses: [String: Placement] = [:]
    var shown: [String: Placement] = [:]
    var travels: [String: LayoutTravel] = [:]
}
