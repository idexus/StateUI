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

    /// Where each hand holds the run on its axis, while it does: what the arithmetic is handed then, the phase
    /// itself named only as the hand passes a target.
    @State private var held: [LayoutInput.Kind: Double] = [:]

    /// Each hand's throw going on after it let go, on its axis, where one does.
    @State private var flung: [LayoutInput.Kind: LayoutFling] = [:]

    /// Where a swiping hand took the run, and the unit it moves it by, while it holds it.
    @State private var grip: LayoutGrip?

    /// The view the hand holds by itself, while it does, and on its way out once dismissed.
    @State private var item: LayoutItemHand?

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

    /// What moves the phase under the user's hand and fingers, one input a kind - a pan's two axes two - and the
    /// axis each moves.
    private var hands: [Given] = []

    /// One input as given: its kind, its gesture, how it throws, and its axis.
    private struct Given {
        let kind: LayoutInput.Kind
        let gesture: LayoutInput.Gesture
        let throwing: Motion
        let axis: WritableKeyPath<Phase, Double>
    }

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

    /// How the hand takes one view by itself, what it is told as it moves it, and which way letting it go far enough
    /// dismisses it.
    private var itemStart: ItemDragStart?
    private var dragged: (@MainActor (ItemDrag<Items.Element>) throws -> Void)?
    private var dismissal: LayoutDismissal<Items.Element>?

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

    /// What moves one axis of the phase under the user's hand or fingers.
    ///
    ///     .input(.scroll(.horizontal, pointsPerUnit: 240), drives: \.turn)
    ///     .input(.magnification, drives: \.zoom)
    ///
    /// The hand moves the axis as it moves, between the lowest and the highest snap target on it - or round and
    /// round where the axis `wraps(_:every:)` - and let go, the run goes on to the target nearest where its throw
    /// would end: it needs `snap(_:to:)` for that axis or `snapTargets(_:)`. Each input moves its own axis alone;
    /// the others go on as the program sends them. The views still answer a tap.
    ///
    /// A layout takes one input an axis, and one of each kind - a hand along the layout or a pan, a magnification,
    /// a rotation: an input given again on its axis, or of its kind, takes the other's place. Two fingers spreading
    /// and turning move their axes at once, and the hand goes on with their middle.
    ///
    /// - Parameters:
    ///   - input: the hand's way of moving the axis.
    ///   - axis: the axis it moves.
    /// - Returns: the layout, moved by the hand.
    public func input(_ input: LayoutInput, drives axis: WritableKeyPath<Phase, Double>) -> Self {
        let kind = input.gesture.kind
        return taking([Given(kind: kind, gesture: input.gesture, throwing: input.throwing, axis: axis)])
    }

    /// What moves two axes of the phase under the user's hand, whichever way it goes: a pan.
    ///
    ///     .input(.pan, drives: \.x, \.y)
    ///     .snap(\.x, to: [0, 1, 2])
    ///     .snap(\.y, to: [0, 1, 2])
    ///
    /// The hand moves the across axis as it moves across and the down axis as it moves down, each between its lowest
    /// and highest snap target - or round and round where it `wraps(_:every:)` - and let go, the run goes on to the
    /// target nearest where its throw would end, both axes together. Two fingers carry it by their middle as they
    /// spread and turn the axes a magnification and a rotation drive. A pan takes the place of a hand along the
    /// layout, and of another pan.
    ///
    /// - Parameters:
    ///   - pan: the hand's way of moving the axes.
    ///   - across: the axis it moves as it goes across - left moving it on.
    ///   - down: the axis it moves as it goes down - up moving it on.
    /// - Returns: the layout, panned by the hand.
    public func input(
        _ pan: LayoutPan, drives across: WritableKeyPath<Phase, Double>, _ down: WritableKeyPath<Phase, Double>
    ) -> Self {
        taking([
            Given(kind: .hand, gesture: .hand(.horizontal, pan.travel, swipes: false), throwing: pan.throwing, axis: across),
            Given(kind: .handDown, gesture: .hand(.vertical, pan.travel, swipes: false), throwing: pan.throwing, axis: down),
        ])
    }

    /// The layout with `given` in place of any input on their axes or of their kinds - a hand along the layout and
    /// a pan one kind.
    private func taking(_ given: [Given]) -> Self {
        var copy = self
        let kinds = Set(given.map(\.kind)).union(given.contains { $0.kind == .hand } ? [.handDown] : [])
        copy.hands.removeAll { each in kinds.contains(each.kind) || given.contains { $0.axis == each.axis } }
        copy.hands += given
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

    /// The hand takes one view by itself, rather than moving the run, when it begins as `start` says: the view drawn
    /// on top under the press follows the hand over the others, and let go goes back to its place under the layout's
    /// motion. A hand that begins any other way moves the run.
    ///
    ///     .itemDrag(begins: .held)
    ///
    /// - Parameter start: a first move across the layout's axis, or a press standing still a long press's time.
    /// - Returns: the layout, its views taken by the hand.
    public func itemDrag(begins start: ItemDragStart) -> Self {
        var copy = self
        copy.itemStart = start
        return copy
    }

    /// Runs as the hand takes a view by itself, each time it moves it, and each time it has stood still a long
    /// press's time more: the item, where the hand is in the room, and how long it has stood still - an order changed
    /// as the hand crosses a slot moves the others, the held view staying under the hand.
    ///
    ///     .onItemDragged { drag in move(drag.item, to: slot(at: drag.at, in: drag.room)) }
    ///
    /// - Parameter handler: what to run, given the drag.
    /// - Returns: the layout, telling the drag.
    public func onItemDragged(_ handler: @escaping @MainActor (ItemDrag<Items.Element>) throws -> Void) -> Self {
        var copy = self
        copy.dragged = handler
        return copy
    }

    /// A view the hand lets go of past `beyond` points `directions` from where it took it - or thrown far enough
    /// that way - flies on out of the room, and `handler` runs with its item once it has left: the application
    /// removes the item then. Let go short of it, the view goes back to its place.
    ///
    ///     .onItemDismissed(.up, beyond: 120) { card in cards.removeAll { $0 == card } }
    ///
    /// - Parameters:
    ///   - directions: the ways a view is dismissed.
    ///   - beyond: how far the hand takes it, in device units, before letting go dismisses it.
    ///   - handler: what to run, given the item, once its view has left the room.
    /// - Returns: the layout, dismissing a view let go far enough.
    public func onItemDismissed(
        _ directions: SwipeDirection, beyond: Double, _ handler: @escaping @MainActor (Items.Element) throws -> Void
    ) -> Self {
        var copy = self
        copy.dismissal = LayoutDismissal(directions: directions, beyond: beyond, handler: handler)
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
        if run.hands.contains(where: \.stops.isEmpty) {
            complain("A LayoutEngine was given a scroll but no snap targets on the axis it drives, which say how far "
                + "it runs and where it rests. The hand moves nothing.")
        }
        if run.hands.contains(where: { $0.kind == .magnification && ($0.stops.first ?? 1) <= 0 }) {
            complain("A LayoutEngine's magnification rests on a target at or below nought, which no spreading of the "
                + "fingers reaches. The fingers move nothing.")
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
            element.describe(
                LayoutEngineContract.handAxis, run.moves && !run.pans ? (run.across ? .horizontal : .vertical) : nil)
            if run.moves {
                element.addHandler(LayoutEngineContract.handMoved) { phase, moved, speed in
                    run.handMoved(phase, moved: moved, speed: speed)
                }
                element.addHandler(LayoutEngineContract.handStepped) { notches in run.stepped(notches) }
            }
            // A pan is heard every way, a hand along the layout one way.
            element.describe(LayoutEngineContract.pans, run.moves && run.pans ? true : nil)
            // Two fingers spreading and turning are heard as one, each moving its own axis.
            let (magnifies, rotates) = (run.on(.magnification) != nil, run.on(.rotation) != nil)
            element.describe(LayoutEngineContract.magnifies, magnifies ? true : nil)
            element.describe(LayoutEngineContract.rotates, rotates ? true : nil)
            if magnifies || rotates {
                element.addHandler(LayoutEngineContract.pinchMoved) { phase, scale, degrees, speed in
                    run.pinch(phase, scale: scale, degrees: degrees, speed: speed)
                }
            }
            element.describe(LayoutEngineContract.itemDrag, run.itemStart)
            if run.itemStart != nil {
                element.addHandler(LayoutEngineContract.itemMoved) { phase, at, speed, still in
                    try run.item(phase, at: at, speed: speed, still: still)
                }
            }
        }
        .setValue(ViewContract.area.token, on: $placements, mode: .out, kind: .placement)
        .setValue(LayoutEngineContract.phase.token, on: run.phase, mode: .inOut, kind: .property)
        .motion(law)
        .frame($room)
        .engine([$room.followed, run.phase.followed, $held.followed, $flung.followed, $item.followed] + followed,
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

    /// What the engine and the handlers are handed: the layout as locals, the hand along it in focus.
    private var run: Run {
        let items = Array(source.items)
        let path = source.path
        let hands = hands.map { given in
            Hand(
                kind: given.kind, axis: given.axis,
                stops: axisTargets[given.axis] ?? Set(targets.map { $0[keyPath: given.axis] }).sorted(),
                period: periods[given.axis], gesture: given.gesture, throwing: given.throwing)
        }

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
            itemStart: itemStart,
            dragged: dragged,
            dismissal: dismissal,
            phase: pinned ?? $ownPhase,
            states: States(
                held: _held, flung: _flung, placements: _placements, room: _room, shown: _shown, from: _from,
                grip: _grip, item: _item),
            hands: hands,
            focus: hands.first { $0.kind == .hand },
            targets: targets,
            axisTargets: axisTargets,
            law: law)
    }

    /// The layout's states, handed on whole: what its engine and handlers read and write.
    struct States {
        let held: State<[LayoutInput.Kind: Double]>
        let flung: State<[LayoutInput.Kind: LayoutFling]>
        let placements: State<PlacedRun>
        let room: State<Rect>
        let shown: State<LayoutShown<Phase>>
        let from: State<Phase?>
        let grip: State<LayoutGrip?>
        let item: State<LayoutItemHand?>
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
