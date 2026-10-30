// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The center of a layout's motion: the views, the arithmetic that places them on the host's frames, the phase it is
// worked out from, and the hand that moves the phase.
// Design: docs/design/views/phase-layout.md

/// Views placed by arithmetic of your own, worked out from a phase the user's hand or the program moves.
///
///     @State private var turn = 0.0
///
///     PhaseLayout(planets, id: \.name, phase: $turn) { planet in
///         Ellipse()
///             .fill(planet.color)
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
///     .axis(\.self, input: .scroll(.horizontal), range: 0...Double(planets.count - 1), snaps: .every(1))
///
/// The phase is a state of yours, two-way: written by the program, the run travels there; under the user's hand it
/// is the snap the run passes, and where it comes to rest. The arithmetic runs on the host's frames whenever the room, the phase or a state named in `following(_:)` moves,
/// with no view built again. It answers one `Placement` per view, in the items' order - where the view goes from
/// the layout's top left, how it is turned, how opaque, which is drawn over which - and each lands as written:
/// what moves smoothly is the phase it is worked out from. A phase of several axes is an `AxesPhase` of your own,
/// each axis moved by its own hand or by the program.
public struct PhaseLayout<Items: RandomAccessCollection, ID: Hashable, Phase: AxesPhase>: View {
    // State first: boxes are adopted by path, and the views stored below may carry boxes of their own.
    // Design: docs/design/views/composition.md#state-declared-first

    /// Where the hand holds each axis it moves, by the axis's place in `axes`, while it does: what the arithmetic is
    /// handed then, the phase itself named only as the hand passes a snap.
    @State private var held: [Int: Double] = [:]

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

    /// The layout's own number for each item's identity, which its frames key the views by.
    @State private var numbers = LayoutSlotNumbers()

    /// Who starts the runs of what `onItemDismissed` asked for, ended with the layout.
    @State private var dismissalRuns = RunOwner()

    /// The items, their views and the arithmetic, behind a class so the state walk stops before them.
    /// Design: docs/design/views/composition.md#items-held-behind-a-class
    private let source: Source

    /// Where the phase is written and read.
    private let phase: Binding<Phase>

    /// The axes the user's hand and fingers move, one declaration an axis.
    private var axes: [Given] = []

    /// One axis as declared: which it is, what moves it, how far it runs, where its layout is worked out, where it
    /// rests, and whether it comes round.
    private struct Given {
        let axis: WritableKeyPath<Phase, Double>
        let input: LayoutInput
        let range: ClosedRange<Double>
        let keyframes: LayoutPlaces?
        let snaps: LayoutPlaces?
        let circular: Bool

        /// What is wrong with the declaration, if anything, as the author is told it.
        var complaint: String? {
            let (low, high) = (range.lowerBound, range.upperBound)
            if !Phase.axes.contains(axis) {
                return "A PhaseLayout was given an axis its phase's `axes` does not list. The hand moves nothing."
            }
            if !low.isFinite || !high.isFinite {
                return "A PhaseLayout's axis was given a range with no end. The hand moves nothing."
            }
            if input.gesture == .magnification, low <= 0 {
                return "A PhaseLayout's magnification was given a range reaching nought, which no spreading of the "
                    + "fingers reaches. The fingers move nothing."
            }
            if circular, input.gesture == .magnification {
                return "A PhaseLayout's magnification was told to come round, which a size never does: it stops at "
                    + "the ends of its range."
            }
            if circular, high <= low {
                return "A PhaseLayout's axis was told to come round over a range of no length: it stays where it is."
            }
            if snaps == nil, case .hand(_, _, swipes: true) = input.gesture {
                return "A PhaseLayout's swipe moves the run one snap a hand, and its axis was given none: it swipes "
                    + "from end to end of its range."
            }
            if circular, keyframes != nil, let knots = hand?.knots, knots.count < 3 {
                return "A PhaseLayout's axis comes round with keyframes at its ends alone, which are one place a "
                    + "turn apart: nothing is blended between them."
            }
            return nil
        }

        /// The axis as the run works on it; nil where the hand cannot move it.
        var hand: Hand? {
            let (low, high) = (range.lowerBound, range.upperBound)
            guard let index = Phase.axes.firstIndex(of: axis), low.isFinite, high.isFinite,
                  input.gesture != .magnification || low > 0
            else { return nil }

            let period = circular && high > low && input.gesture != .magnification ? high - low : nil
            let swipes = if case .hand(_, _, swipes: true) = input.gesture { true } else { false }
            let snaps = snaps ?? (swipes ? .limits : nil)
            let knots = keyframes.map { keyframes in
                Array(Set(keyframes.values(in: range, circular: false) + (snaps?.values(in: range, circular: false) ?? [])))
                    .sorted()
            }
            return Hand(
                index: index, axis: axis, gesture: input.gesture, throwing: input.throwing, low: low, high: high,
                stops: snaps?.values(in: range, circular: period != nil) ?? [], period: period, knots: knots)
        }
    }

    /// What is wrong with the axes as declared, as the author is told it.
    private var complaints: [String] {
        let blends = curve != nil && !axes.contains { $0.keyframes != nil }
        return axes.compactMap { $0.complaint } + (blends
            ? ["A PhaseLayout was given an interpolation and no axis with keyframes: nothing is blended."]
            : [])
    }

    /// The curve between the poses at the axes' keyframes, where one was given.
    private var curve: (any LayoutInterpolation)?

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

    /// What the views move by between where the arithmetic puts them and where they are shown.
    private var world = PhysicsWorld.standard

    /// Whether the layout turns about its middle where it lays out right to left.
    private var mirrors = false

    /// What a target the run names is told to beside the phase: a composed control's own value worked out from it.
    private var named: ((Phase) -> Void)?

    /// A layout of views, one per item, placed by `placements` on the host's frames.
    ///
    /// - Parameters:
    ///   - items: what to place, one view each.
    ///   - id: which part of an item is its identity - distinct across the items, and stable while the item means
    ///     the same view, so a view keeps its place and its state when the items change.
    ///   - phase: the state the arithmetic is worked out from, which the program and the user's hand move.
    ///   - content: the view for one item.
    ///   - placements: where every view goes, given the room - from the layout's top left, at its size - and the
    ///     phase as it stands this frame; one placement per view, in the items' order.
    public init<Content: View>(
        _ items: Items,
        id: KeyPath<Items.Element, ID>,
        phase: Binding<Phase>,
        @ViewBuilder content: @escaping (Items.Element) -> Content,
        placements: @escaping @MainActor (Rect, Phase) -> [Placement]
    ) {
        self.phase = phase
        source = Source(
            items: items, path: id, view: { content($0).node }, holder: { LayoutItemView(content: content($0)).node }, arithmetic: { room, phase, _ in placements(room, phase) },
            readsFrom: false)
    }

    /// The same, for items that are their own identity.
    ///
    ///     PhaseLayout(["Mural", "Ridge"], phase: $turn) { Text($0) } placements: { room, _ in … }
    ///
    /// - Parameters:
    ///   - items: what to place, one view each.
    ///   - phase: the state the arithmetic is worked out from.
    ///   - content: the view for one item.
    ///   - placements: where every view goes, given the room and the phase.
    public init<Content: View>(
        _ items: Items,
        phase: Binding<Phase>,
        @ViewBuilder content: @escaping (Items.Element) -> Content,
        placements: @escaping @MainActor (Rect, Phase) -> [Placement]
    ) where Items.Element: Hashable, ID == Items.Element {
        self.init(items, id: \.self, phase: phase, content: content, placements: placements)
    }

    /// A layout whose arithmetic is handed, beside the phase, where the run's motion set out: the phase it stood
    /// at when the hand, a throw or a journey took it away, then each snap the run passes on an axis the hand moves.
    ///
    ///     PhaseLayout(cards, id: \.name, phase: $turn) { card in Face(card) } placements: { room, phase, from in
    ///         // The card that stood in front leaves the way the run goes - phase above `from` or below it.
    ///     }
    ///
    /// The way the run goes is the phase's side of `from`; back past it, the run goes the other way from the same
    /// place, and at `from` itself every view stands where it stood, so nothing drawn from it jumps.
    ///
    /// - Parameters:
    ///   - items: what to place, one view each.
    ///   - id: which part of an item is its identity.
    ///   - phase: the state the arithmetic is worked out from.
    ///   - content: the view for one item.
    ///   - placements: where every view goes, given the room, the phase as it stands this frame and the phase the
    ///     run's motion set out from; one placement per view, in the items' order.
    public init<Content: View>(
        _ items: Items,
        id: KeyPath<Items.Element, ID>,
        phase: Binding<Phase>,
        @ViewBuilder content: @escaping (Items.Element) -> Content,
        placements: @escaping @MainActor (Rect, Phase, Phase) -> [Placement]
    ) {
        self.phase = phase
        source = Source(items: items, path: id, view: { content($0).node }, holder: { LayoutItemView(content: content($0)).node }, arithmetic: placements, readsFrom: true)
    }

    /// The same, for items that are their own identity.
    public init<Content: View>(
        _ items: Items,
        phase: Binding<Phase>,
        @ViewBuilder content: @escaping (Items.Element) -> Content,
        placements: @escaping @MainActor (Rect, Phase, Phase) -> [Placement]
    ) where Items.Element: Hashable, ID == Items.Element {
        self.init(items, id: \.self, phase: phase, content: content, placements: placements)
    }

    /// One axis of the phase under the user's hand or fingers: what moves it, how far it runs, where its layout is
    /// worked out, where it comes to rest and whether it comes round.
    ///
    ///     .axis(\.self, input: .swipe(.horizontal), range: 0...Double(cards.count - 1), snaps: .every(1))
    ///     .axis(\.zoom, input: .magnification, range: 0.5...2)
    ///     .axis(\.turn, input: .rotation(degreesPerUnit: 360), range: 0...1, snaps: .every(0.25), circular: true)
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
    /// Given keyframes, the arithmetic is asked only there - at them, the range's ends and the snaps - and the
    /// layout is blended between its answers along `interpolation(_:)`: quite different layouts, one at each
    /// keyframe, become one the hand moves through.
    ///
    ///     .axis(\.self, input: .scroll(.horizontal), range: 0...2, keyframes: .every(1), snaps: .limits)
    ///
    /// - Parameters:
    ///   - axis: the axis, one of the phase's `axes`; `\.self` for a `Double` phase.
    ///   - input: what moves it.
    ///   - range: how far the hand moves it; above nought for a magnification.
    ///   - keyframes: where the arithmetic is asked beside the ends of the range and the snaps; every frame unless
    ///     said.
    ///   - snaps: where it may rest beside the ends of its range; anywhere inside it unless said.
    ///   - circular: whether its end meets its start, its range one turn.
    /// - Returns: the layout, its axis moved by the hand.
    public func axis(
        _ axis: WritableKeyPath<Phase, Double>,
        input: LayoutInput,
        range: ClosedRange<Double>,
        keyframes: LayoutPlaces? = nil,
        snaps: LayoutPlaces? = nil,
        circular: Bool = false
    ) -> Self {
        var copy = self
        copy.axes.removeAll { $0.axis == axis }
        copy.axes.append(
            Given(axis: axis, input: input, range: range, keyframes: keyframes, snaps: snaps, circular: circular))
        return copy
    }

    /// The curve every view follows between the poses the arithmetic answers at the axes' keyframes: straight
    /// unless said.
    ///
    ///     .axis(\.self, input: .scroll(.horizontal), range: 0...2, keyframes: .every(1))
    ///     .interpolation(.catmullRom)
    ///
    /// Each view goes from its pose at one keyframe to its pose at the next by its identity: its place and size,
    /// its turn - the short way - its scale, opacity and shade, and the drawing order swapping as the views'
    /// `zIndex` cross.
    ///
    /// - Parameter curve: `.linear`, `.catmullRom`, `.monotone`, or a curve of your own.
    /// - Returns: the layout, blended along the curve.
    public func interpolation(_ curve: some LayoutInterpolation) -> Self {
        var copy = self
        copy.curve = curve
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
    ///     .shade(
    ///         Rectangle()
    ///             .fill(.black)
    ///             .cornerRadius(14))
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

    /// How the phase travels where the program or a settle sends it; let go short of the next snap, the run comes
    /// onto it at a unit a length of this motion, so the short way is short. How a view a change moves comes onto its
    /// new place is the world's (`physicsWorld(_:)`).
    ///
    ///     .motion(.spring(response: .milliseconds(240)))
    ///
    /// - Parameter motion: the law; the element's, the application's or the library's unless said.
    /// - Returns: the layout, traveling that way.
    public func motion(_ motion: Motion) -> Self {
        var copy = self
        copy.law = motion
        return copy
    }

    /// What the views move by between where the arithmetic puts them and where they are shown: a view a change
    /// moves - joining, the run arranged anew, let go by the hand - comes onto its new place as a body of this
    /// world, and one with a body of its own (`physicsBody(_:)`) as that body says.
    ///
    ///     .physicsWorld(.spring(response: .milliseconds(420), damping: 0.8))
    ///
    /// - Parameter world: the world; `.standard` unless said, `.none` for views standing at their places at once.
    /// - Returns: the layout, its views moving by that world.
    public func physicsWorld(_ world: PhysicsWorld) -> Self {
        var copy = self
        copy.world = world
        return copy
    }

    /// Whether the layout follows the direction its language is read in, as a stack does: laid out right to left,
    /// it turns about its middle - each view's place, its move along and its turn - and the hand over it turns
    /// with it, so the arithmetic stays left to right.
    ///
    ///     PhaseLayout(albums, id: \.title, phase: $shown) { AlbumFace($0) } placements: { room, phase in … }
    ///         .mirrorsRightToLeft(true)   // the next album stands on the left in Arabic
    ///
    /// A layout places its views as written unless it says so: a dial, a clock or a table of photos keeps its
    /// shape in every language.
    ///
    /// - Parameter mirrors: whether to turn right to left.
    /// - Returns: the layout, mirrored right to left or not.
    public func mirrorsRightToLeft(_ mirrors: Bool) -> Self {
        var copy = self
        copy.mirrors = mirrors
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

    /// The same, with a handler that awaits: its `policy` says what a tap does while a run is under way.
    public func onItemTapped(_ policy: GatePolicy, _ handler: @escaping ValueEventHandler<Items.Element>) -> Self {
        var copy = self
        copy.tapped = ValueHandler(run: handler, gate: .own(policy))
        return copy
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onItemTapped(gate: Gate, _ handler: @escaping ValueEventHandler<Items.Element>) -> Self {
        var copy = self
        copy.tapped = ValueHandler(run: handler, gate: .shared(gate))
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
        copy.dismissal = LayoutDismissal(directions: directions, beyond: beyond, handler: ValueHandler(step: handler))
        return copy
    }

    /// The same, with a handler that awaits - an archive does: its `policy` says what another view dismissed does
    /// while a run is under way.
    ///
    ///     .onItemDismissed(.up, beyond: 120, policy: .cancelPrevious) { card in try await archive(card) }
    public func onItemDismissed(
        _ directions: SwipeDirection, beyond: Double, policy: GatePolicy,
        _ handler: @escaping ValueEventHandler<Items.Element>
    ) -> Self {
        var copy = self
        copy.dismissal = LayoutDismissal(
            directions: directions, beyond: beyond, handler: ValueHandler(run: handler, gate: .own(policy)))
        return copy
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onItemDismissed(
        _ directions: SwipeDirection, beyond: Double, gate: Gate,
        _ handler: @escaping ValueEventHandler<Items.Element>
    ) -> Self {
        var copy = self
        copy.dismissal = LayoutDismissal(
            directions: directions, beyond: beyond, handler: ValueHandler(run: handler, gate: .shared(gate)))
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
        let mirrors = self.mirrors

        if Phase.axes.isEmpty {
            complain("A PhaseLayout's phase names no axes: `axes` lists the numbers the hand and the program move.")
        }
        for complaint in complaints { complain(complaint) }
        if phase.followed == nil {
            complain("A PhaseLayout's phase is a state lent with `$`: a binding worked out from others cannot be "
                + "worn, so the phase would jump where it is sent rather than travel there.")
        }

        return PlacedStack {
            ForEach(run.slots, identify: { $0.identity }) { slot in run.wrapped(slot) }
        }
        .modified { element in
            // The hand is heard on the element itself, over every view, which still answers a tap.
            element.describe(PhaseLayoutContract.handAxis, run.ways.count == 1 ? run.ways.first : nil)
            element.describe(PhaseLayoutContract.mirrorsRightToLeft, mirrors ? true : nil)
            // What a dismissal asked for ends with the layout.
            if run.dismissal != nil { element.destroying.append { run.states.dismissals.orphan() } }
            if run.moves {
                element.addHandler(PhaseLayoutContract.handMoved) { phase, moved, speed in
                    run.handMoved(phase, moved: moved, speed: speed)
                }
                element.addHandler(PhaseLayoutContract.handStepped) { notches in run.stepped(notches) }
            }
            // A pan is heard every way, a hand along the layout one way.
            element.describe(PhaseLayoutContract.pans, run.pans ? true : nil)
            // Two fingers spreading and turning are heard as one, each moving its own axes.
            let magnifies = run.hands.contains { $0.gesture == .magnification }
            let rotates = run.hands.contains { if case .rotation = $0.gesture { true } else { false } }
            element.describe(PhaseLayoutContract.magnifies, magnifies ? true : nil)
            element.describe(PhaseLayoutContract.rotates, rotates ? true : nil)
            if magnifies || rotates {
                element.addHandler(PhaseLayoutContract.pinchMoved) { phase, scale, degrees, speed in
                    run.pinch(phase, scale: scale, degrees: degrees, speed: speed)
                }
            }
            element.describe(PhaseLayoutContract.itemDrag, run.itemStart)
            if run.itemStart != nil {
                element.addHandler(PhaseLayoutContract.itemMoved) { phase, at, speed, still in
                    try run.item(phase, at: at, speed: speed, still: still)
                }
            }
        }
        .setValue(ViewContract.area.token, on: $placements, mode: .out, kind: .placement)
        .setValue(PhaseLayoutContract.phase.token, on: run.phase, mode: .inOut, kind: .property)
        .motion(law)
        .frame($room)
        .engine([$room.followed, run.phase.followed, $held.followed, $item.followed] + followed,
                priority: 0) { cycle in
            run.place(at: cycle.now, reducesMotion: cycle.reducesMotion)
        }
    }

    /// What the initializer was handed, behind a reference. See `source`.
    private final class Source {
        /// What to place, one view each.
        let items: Items

        /// Which part of an item is its identity.
        let path: KeyPath<Items.Element, ID>

        /// The view for one item, as a node, and in the holder the run places as a view of its own.
        let view: (Items.Element) -> Node
        let holder: (Items.Element) -> Node

        /// Where every view goes, given the room, the phase and where its motion set out.
        let arithmetic: @MainActor (Rect, Phase, Phase) -> [Placement]

        /// Which description this is: the next number at each, never one again - an object's address is, once it
        /// is let go.
        let number: Int

        /// Whether the arithmetic is handed where the motion set out, and the poses it answered at keyframes, kept
        /// while this description stands.
        let readsFrom: Bool
        let kept = LayoutPoses()

        /// The body each view says it is (`physicsBody(_:)`), in the items' order: read off the views the first time a
        /// frame asks, once for this description.
        private var bodies: [PhysicsBody?]?

        /// The body the view at `index` says it is; nil for one of the world's own.
        @MainActor
        func body(at index: Int) -> PhysicsBody? {
            let bodies = self.bodies ?? items.map { item in
                view(item).props[ViewContract.physicsBody.token].flatMap(PhysicsBody.init(propValue:))
            }
            self.bodies = bodies
            return bodies.indices.contains(index) ? bodies[index] : nil
        }

        /// What the initializer was handed.
        @MainActor
        init(
            items: Items,
            path: KeyPath<Items.Element, ID>,
            view: @escaping (Items.Element) -> Node,
            holder: @escaping (Items.Element) -> Node,
            arithmetic: @escaping @MainActor (Rect, Phase, Phase) -> [Placement],
            readsFrom: Bool
        ) {
            self.items = items
            self.path = path
            self.view = view
            self.holder = holder
            self.arithmetic = arithmetic
            self.readsFrom = readsFrom
            descriptionsMade += 1
            number = descriptionsMade
        }
    }

    /// What the engine and the handlers are handed: the layout as locals, the hand along it in focus.
    var run: Run {
        let items = Array(source.items)
        let path = source.path
        // Closures, not key paths: one written in a generic type is made anew at every call.
        let hands = axes.compactMap { $0.hand }
        let identities = numbers.numbered(items.map { AnyHashable($0[keyPath: path]) })

        return Run(
            items: items,
            slots: zip(items, identities).enumerated().map { offset, item in
                Slot(identity: item.1, index: offset, item: item.0)
            },
            make: source.view,
            holder: source.holder,
            arithmetic: source.arithmetic,
            curve: curve ?? LayoutCurve.linear,
            readsFrom: source.readsFrom,
            kept: source.kept,
            followed: followed.compactMap { $0 },
            description: source.number,
            mask: mask,
            tapped: tapped,
            named: named,
            itemStart: itemStart,
            dragged: dragged,
            dismissal: dismissal,
            phase: phase,
            states: States(
                held: _held, placements: _placements, room: _room, shown: _shown, from: _from,
                grip: _grip, item: _item, dismissals: dismissalRuns),
            hands: hands,
            focus: hands.first { $0.way != nil },
            law: law,
            world: world,
            body: { [source] index in source.body(at: index) })
    }

    /// The layout's states, handed on whole: what its engine and handlers read and write.
    struct States {
        let held: State<[Int: Double]>
        let placements: State<PlacedRun>
        let room: State<Rect>
        let shown: State<LayoutShown<Phase>>
        let from: State<Phase?>
        let grip: State<[Int: LayoutGrip]>
        let item: State<LayoutItemHand?>
        let dismissals: RunOwner
    }
}

extension PhaseLayout: WalkedView {
    /// The parts the walk reads, as a mirror would list them, with no mirror made: a mirror of a generic type works
    /// its fields' types out at every reading, and every render of a layout walks its engine
    /// (`PhaseLayoutTests.testTheEngineNamesEveryPartAMirrorWould` holds the list to the fields).
    var walkedParts: [(label: String, value: Any)] {
        [
            ("_held", _held), ("_grip", _grip), ("_item", _item),
            ("_placements", _placements), ("_shown", _shown), ("_from", _from), ("_room", _room), ("_numbers", _numbers),
            ("_dismissalRuns", _dismissalRuns),
            ("source", source), ("phase", phase), ("axes", axes), ("curve", curve as Any),
            ("followed", followed), ("mask", mask as Any), ("tapped", tapped as Any),
            ("itemStart", itemStart as Any), ("dragged", dragged as Any), ("dismissal", dismissal as Any),
            ("law", law), ("world", world), ("mirrors", mirrors), ("named", named as Any),
        ]
    }
}

/// How many descriptions of phase layouts have been made.
@MainActor private var descriptionsMade = 0

/// Where a swiping hand took the run - the target nearest, one either side of which it moves it - and the unit it
/// moves it by, measured there; nil for none the hand can measure.
struct LayoutGrip: Equatable {
    let target: Double
    let unit: Double?
}

/// What a layout last showed - the description it came from, at what phase, set out from where and in what room,
/// each view's pose and where it was shown, by identity - and the changes on their way to the poses: what a new
/// description is measured against.
struct LayoutShown<Phase: AxesPhase>: Equatable {
    var description: Int?
    var phase: Phase?
    var from: Phase?
    var room = Rect.zero
    var poses: [Int: Placement] = [:]
    var shown: [Int: Placement] = [:]
    var bodies = LayoutBodies()
}
