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
///     .axis(\.self, input: .scroll(.horizontal), range: 0...Double(planets.count - 1), snaps: .every(1))
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

    /// Where the hand holds each axis it moves, by the axis's place in `axes`, while it does: what the arithmetic is
    /// handed then, the phase itself named only as the hand passes a snap.
    @State private var held: [Int: Double] = [:]

    /// Each axis's throw going on after the hand let go, where one does.
    @State private var flung: [Int: LayoutFling] = [:]

    /// Where a swiping hand took each axis, and the unit it moves it by, while it holds it.
    @State private var grip: [Int: LayoutGrip] = [:]

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

    /// The axes the user's hand and fingers move, one declaration an axis.
    private var axes: [Given] = []

    /// One axis as declared: which it is, what moves it, how far it runs, where it rests, and whether it comes round.
    private struct Given {
        let axis: WritableKeyPath<Phase, Double>
        let input: LayoutInput
        let range: ClosedRange<Double>
        let snaps: LayoutSnaps?
        let wraps: Bool

        /// What is wrong with the declaration, if anything, as the author is told it.
        var complaint: String? {
            let (low, high) = (range.lowerBound, range.upperBound)
            if !Phase.axes.contains(axis) {
                return "A LayoutEngine was given an axis its phase's `axes` does not list. The hand moves nothing."
            }
            if !low.isFinite || !high.isFinite {
                return "A LayoutEngine's axis was given a range with no end. The hand moves nothing."
            }
            if input.gesture == .magnification, low <= 0 {
                return "A LayoutEngine's magnification was given a range reaching nought, which no spreading of the "
                    + "fingers reaches. The fingers move nothing."
            }
            if wraps, input.gesture == .magnification {
                return "A LayoutEngine's magnification was told to come round, which a size never does: it stops at "
                    + "the ends of its range."
            }
            if wraps, high <= low {
                return "A LayoutEngine's axis was told to come round over a range of no length: it stays where it is."
            }
            if snaps == nil, case .hand(_, _, swipes: true) = input.gesture {
                return "A LayoutEngine's swipe moves the run one snap a hand, and its axis was given none: it swipes "
                    + "from end to end of its range."
            }
            return nil
        }

        /// The axis as the run works on it; nil where the hand cannot move it.
        var hand: Hand? {
            let (low, high) = (range.lowerBound, range.upperBound)
            guard let index = Phase.axes.firstIndex(of: axis), low.isFinite, high.isFinite,
                  input.gesture != .magnification || low > 0
            else { return nil }

            let period = wraps && high > low && input.gesture != .magnification ? high - low : nil
            let swipes = if case .hand(_, _, swipes: true) = input.gesture { true } else { false }
            let snaps = snaps ?? (swipes ? .limits : nil)
            return Hand(
                index: index, axis: axis, gesture: input.gesture, throwing: input.throwing, low: low, high: high,
                stops: snaps?.stops(in: range, wraps: period != nil) ?? [], period: period)
        }
    }

    /// What is wrong with the axes as declared, as the author is told it.
    private var complaints: [String] { axes.compactMap(\.complaint) }

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
    /// at when the hand, a throw or a journey took it away, then each snap the run passes on an axis the hand moves.
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
    /// Written by the program, the run travels there. Under the user's hand it is the snap the run passes,
    /// and where it comes to rest; the arithmetic is handed the phase as it stands each frame.
    ///
    /// - Parameter state: where the phase is written and read.
    /// - Returns: the layout, worked out from that phase.
    public func phase(_ state: Binding<Phase>) -> Self {
        var copy = self
        copy.pinned = state
        return copy
    }

    /// One axis of the phase under the user's hand or fingers: what moves it, how far it runs, where it comes to
    /// rest and whether it comes round.
    ///
    ///     .axis(\.self, input: .swipe(.horizontal), range: 0...Double(cards.count - 1), snaps: .every(1))
    ///     .axis(\.zoom, input: .magnification, range: 0.5...2)
    ///     .axis(\.turn, input: .rotation(degreesPerUnit: 360), range: 0...1, snaps: .every(0.25), wraps: true)
    ///
    /// The hand moves the axis freely inside its range - less and less past an end, which it comes back onto when
    /// let go - and let go, the run goes on to where its throw would end: the snap nearest it, where the axis has
    /// snaps. Wrapping, the axis has no end: one turn of the range's length brings the layout back to where it was,
    /// so the hand moves it on for ever - `turn` 9 of seven cards is the third, a turn on, so a write of one more
    /// always travels one card on. The program writes the axis anywhere; the range and the snaps are the hand's.
    ///
    /// Each axis is moved by its own input alone, and one input may move several axes - a hand moving the photos
    /// and, slower, the sky behind them. Two axes scrolled one across and one down are a pan: the hand moves both,
    /// whichever way it goes. Two fingers spreading and turning move their axes at once, and the hand goes on with
    /// their middle. An axis declared again takes the other's place; the axes declared none go on as the program
    /// sends them. The views still answer a tap.
    ///
    /// - Parameters:
    ///   - axis: the axis, one of the phase's `axes`; `\.self` for a `Double` phase.
    ///   - input: what moves it.
    ///   - range: how far the hand moves it; above nought for a magnification.
    ///   - snaps: where it may rest beside the ends of its range; anywhere inside it unless said.
    ///   - wraps: whether it comes round, its range one turn.
    /// - Returns: the layout, its axis moved by the hand.
    public func axis(
        _ axis: WritableKeyPath<Phase, Double>,
        input: LayoutInput,
        range: ClosedRange<Double>,
        snaps: LayoutSnaps? = nil,
        wraps: Bool = false
    ) -> Self {
        var copy = self
        copy.axes.removeAll { $0.axis == axis }
        copy.axes.append(Given(axis: axis, input: input, range: range, snaps: snaps, wraps: wraps))
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

    /// How the run travels where the program or a settle sends it; let go short of the next snap, the run comes
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
        for complaint in complaints { complain(complaint) }
        if let pinned, pinned.followed == nil {
            complain("A LayoutEngine's phase is a state lent with `$`: a binding worked out from others cannot be "
                + "worn, so the phase would jump where it is sent rather than travel there.")
        }

        return PlacedStack {
            ForEach(run.slots, id: \.identity) { slot in run.wrapped(slot) }
        }
        .modified { element in
            // The hand is heard on the element itself, over every view, which still answers a tap.
            element.describe(LayoutEngineContract.handAxis, run.ways.count == 1 ? run.ways.first : nil)
            if run.moves {
                element.addHandler(LayoutEngineContract.handMoved) { phase, moved, speed in
                    run.handMoved(phase, moved: moved, speed: speed)
                }
                element.addHandler(LayoutEngineContract.handStepped) { notches in run.stepped(notches) }
            }
            // A pan is heard every way, a hand along the layout one way.
            element.describe(LayoutEngineContract.pans, run.pans ? true : nil)
            // Two fingers spreading and turning are heard as one, each moving its own axes.
            let magnifies = run.hands.contains { $0.gesture == .magnification }
            let rotates = run.hands.contains { if case .rotation = $0.gesture { true } else { false } }
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
        let hands = axes.compactMap(\.hand)

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
            focus: hands.first { $0.way != nil },
            law: law)
    }

    /// The layout's states, handed on whole: what its engine and handlers read and write.
    struct States {
        let held: State<[Int: Double]>
        let flung: State<[Int: LayoutFling]>
        let placements: State<PlacedRun>
        let room: State<Rect>
        let shown: State<LayoutShown<Phase>>
        let from: State<Phase?>
        let grip: State<[Int: LayoutGrip]>
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
