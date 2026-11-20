// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The center of a layout's motion: the views, the arithmetic that places them on the host's frames, the parameters it
// is worked out from, and the hand that moves the parameters.
// Design: docs/design/views/motion-layout.md

/// Views placed by arithmetic of your own, worked out from parameters the user's hand or the program moves.
///
///     @State private var turn = 0.0
///
///     MotionLayout(planets, id: \.name, parameters: $turn) { planet in
///         Ellipse()
///             .fill(planet.color)
///     } placements: { context, parameters in
///         planets.indices.map { index in
///             let angle = (Double(index) - parameters) / Double(planets.count) * 2 * .pi
///             let radius = min(room.width, room.height) / 2 - 40
///
///             return Placement(Rect(
///                 room.width / 2 + cos(angle) * radius - 24,
///                 room.height / 2 + sin(angle) * radius - 24,
///                 48,
///                 48))
///         }
///     }
///     .interaction(
///         .value($turn, axis: \.self, input: .translation(.horizontal, unit: .frontItem))
///             .reversed(true).range(0...Double(planets.count - 1)).snaps(.every(1)))
///
/// The parameters are a state of yours, two-way: written by the program, the run travels there; under the user's hand
/// they are the snap the run passes, and where it comes to rest. The arithmetic runs on the host's frames whenever the
/// room, the parameters or a state named in `following(_:)` moves, with no view built again. It answers one `Placement`
/// per view, in the items' order - where the view goes from the layout's top left, how it is turned, how opaque, which
/// is drawn over which - and each lands as written: what moves smoothly are the parameters it is worked out from.
/// Parameters of several axes are a `LayoutParameters` of your own, each axis moved by its own hand or by the program.
public struct MotionLayout<Items: RandomAccessCollection, ID: Hashable, Parameters: LayoutParameters>: View {
    // State first: boxes are adopted by path, and the views stored below may carry boxes of their own.
    // Design: docs/design/views/composition.md#state-declared-first

    /// The view the hand holds by itself, while it does, and on its way out once dismissed.
    @State private var item: LayoutItemHand?

    /// The layout's slot: its number, the room the host said last and where the run last put every child.
    /// Design: docs/design/core/layout-program.md#the-program
    @State private var slot = LayoutProgramSlot()

    /// What the run last showed and the changes on their way to its poses.
    @State private var shown = LayoutShown<Parameters>()

    /// The parameters the run stood at when its motion set out, kept until it rests again.
    @State private var from: Parameters?

    /// The room the host laid the layout out in, as its program was last told.
    @State private var room = Rect.zero

    /// The layout's own number for each item's identity, which its frames key the views by.
    @State private var numbers = LayoutSlotNumbers()

    /// The runs of what `onItemDismissed` asked for, each handler's its own, ended with the layout.
    @State private var dismissalRuns = EventRegistration([])

    /// The runs of the handlers told the run came to rest, each its own.
    @State private var settledRuns = EventRegistration([])

    /// The runs of the handlers told the hand moves a view, each its own.
    @State private var dragRuns = EventRegistration([])

    /// The items, their views and the arithmetic, behind a class so the state walk stops before them.
    /// Design: docs/design/views/composition.md#items-held-behind-a-class
    private let source: Source

    /// Where the parameters are written and read.
    private let parameters: Binding<Parameters>

    /// The axes the layout maps by keyframes or segments, one declaration an axis (`axis`).
    private var mappings: [Mapping] = []

    /// What the user's hand and fingers move, as declared (`interaction(_:)`).
    private var declared: Interaction?

    /// One axis as the layout maps it: how far the mapping runs, where the arithmetic is asked, where its segments
    /// begin and whether it comes round.
    private struct Mapping {
        let axis: WritableKeyPath<Parameters, Double>
        let range: ClosedRange<Double>
        let keyframes: AxisValues?
        let segments: AxisValues?
        let periodic: Bool

        /// What is wrong with the declaration, if anything, as the author is told it.
        var complaint: String? {
            let (low, high) = (range.lowerBound, range.upperBound)
            if !Parameters.axes.contains(axis) {
                return "A MotionLayout was given an axis its parameters' `axes` do not list. Nothing maps it."
            }
            if !low.isFinite || !high.isFinite {
                return "A MotionLayout's axis was given a range with no end. Nothing maps it."
            }
            if keyframes == nil, segments == nil {
                return "A MotionLayout's axis was given no keyframes and no segments: the declaration changes nothing."
            }
            if periodic, high <= low {
                return "A MotionLayout's axis was told to come round over a range of no length: it stays where it is."
            }
            if periodic, keyframes != nil, (knots?.count ?? 0) < 3 {
                return "A MotionLayout's axis comes round with keyframes at its ends alone, which are one place a "
                    + "turn apart: nothing is blended between them."
            }
            return nil
        }

        /// Whether the declaration maps anything.
        var stands: Bool {
            Parameters.axes.contains(axis) && range.lowerBound.isFinite && range.upperBound.isFinite
        }

        /// How far one turn takes the axis, where it comes round.
        var period: Double? { periodic && range.upperBound > range.lowerBound ? range.upperBound - range.lowerBound : nil }

        /// Where the arithmetic is asked, lowest first, the ends included; nil for every frame.
        var knots: [Double]? { keyframes?.values(in: range, periodic: false) }

        /// Where the axis's segments begin, lowest first - one turn's, where it comes round.
        var marks: [Double] { segments?.values(in: range, periodic: period != nil) ?? [] }
    }

    /// The axes as the run works on them - each the hand moves, and each mapped alone - with what is wrong with the
    /// declarations, as the author is told it.
    /// Design: docs/design/views/interaction.md#on-a-motion-layout
    private var worked: (hands: [Hand], complaints: [String], moving: [Interaction.Leaf]) {
        var complaints = (declared?.refused ?? []) + mappings.compactMap { $0.complaint }
        if curve != nil, !mappings.contains(where: { $0.keyframes != nil }) {
            complaints.append("A MotionLayout was given an interpolation and no axis with keyframes: nothing is blended.")
        }
        let own = ObjectIdentifier(parameters.storage)
        var moved: [(index: Int, leaf: Interaction.Leaf)] = []
        for leaf in declared?.leaves ?? [] {
            guard leaf.state == own, let axis = leaf.axis as? WritableKeyPath<Parameters, Double>,
                  let index = Parameters.axes.firstIndex(of: axis)
            else {
                complaints.append(
                    "A MotionLayout's interaction moves a number that is no axis of the layout's parameters. The hand "
                        + "moves nothing of it.")
                continue
            }
            moved.append((index, leaf))
        }
        // Two moving one number are refused together: neither is the one the author meant.
        let twice = Set(Dictionary(grouping: moved, by: \.index).filter { $0.value.count > 1 }.keys)
        if !twice.isEmpty {
            complaints.append(
                "A MotionLayout's interaction moves one number of its parameters twice. The hand moves nothing of it.")
        }

        var hands: [Hand] = []
        var moving: [Interaction.Leaf] = []
        for (index, leaf) in moved where !twice.contains(index) {
            let mapping = mappings.last { $0.stands && Parameters.axes.firstIndex(of: $0.axis) == index }
            if let complaint = Self.complaint(of: leaf) {
                complaints.append(complaint)
                continue
            }
            hands.append(Self.hand(at: index, moved: leaf, mapped: mapping))
            moving.append(leaf)
        }
        for mapping in mappings where mapping.stands {
            guard let index = Parameters.axes.firstIndex(of: mapping.axis), !hands.contains(where: { $0.index == index })
            else { continue }
            hands.append(Self.hand(at: index, moved: nil, mapped: mapping))
        }
        return (hands, complaints, moving)
    }

    /// What is wrong with one value an interaction moves, if anything, as the author is told it.
    private static func complaint(of leaf: Interaction.Leaf) -> String? {
        let magnifies = leaf.input.gesture == .magnification
        if let range = leaf.range {
            if !range.lowerBound.isFinite || !range.upperBound.isFinite {
                return "An interaction was given a range with no end. The hand moves nothing of it."
            }
            if magnifies, range.lowerBound <= 0 {
                return "An interaction's magnification was given a range reaching nought, which no spreading of the "
                    + "fingers reaches. The fingers move nothing."
            }
        }
        if leaf.periodic, magnifies {
            return "An interaction's magnification was told to come round, which a size never does. The fingers move "
                + "nothing."
        }
        if leaf.periodic, (leaf.range.map { $0.upperBound > $0.lowerBound } ?? false) == false {
            return "An interaction was told to come round with no range of some length to come round over. The hand "
                + "moves nothing of it."
        }
        if leaf.input.swipes, leaf.snaps == nil {
            return "An interaction's swipe moves its value one snap a hand, and was given no snaps. The hand moves "
                + "nothing of it."
        }
        if let snaps = leaf.snaps, leaf.range == nil, snaps.unbounded == nil {
            return "An interaction was given the ends of a range, and no range, to rest at. The hand moves nothing "
                + "of it."
        }
        return nil
    }

    /// The axis at `index` as the run works on it: moved as `leaf` says, mapped as `mapping` does.
    private static func hand(at index: Int, moved leaf: Interaction.Leaf?, mapped mapping: Mapping?) -> Hand {
        var way: Orientation?
        if case .hand(let moved, _, _)? = leaf?.input.gesture { way = moved }
        let span = mapping.map { Hand.Span(low: $0.range.lowerBound, high: $0.range.upperBound, period: $0.period) }
        return Hand(
            index: index, axis: Parameters.axes[index], way: way, release: leaf?.release ?? .standard,
            knots: mapping?.knots, span: span, segments: mapping?.marks ?? [])
    }

    /// The curve between the poses at the axes' keyframes, where one was given.
    private var curve: (any LayoutInterpolation)?

    /// States whose writes - and journeys whose frames - run the arithmetic again on the host's frames.
    private var followed: [any FollowedState] = []

    /// The journeys the layout follows, each a consumer of its channel while the layout stands.
    private var consumed: [JourneyConsumer] = []

    /// What is drawn over each view at its placement's `shade`, if anything.
    private var mask: Node?

    /// What runs when the user taps a view, through its gate.
    private var activated: [ValueHandler<ID>] = []

    /// How the hand takes one view by itself, what it is told as it moves it, and which way letting it go far enough
    /// dismisses it.
    private var itemStart: ItemDragStart?
    private var dragged: [ValueHandler<ItemDrag<ID>>] = []
    private var dismissals: [LayoutDismissal<ID>] = []

    /// What is told once the run comes to rest.
    private var settled: [ValueHandler<Parameters>] = []

    /// The layout's own size, where it says one (`measure(_:)`); nil for a layout taking the room it is given.
    private var sized: (@MainActor (LayoutMeasurementContext<ID>, Parameters) -> LayoutSize)?

    /// Whether the layout turns about its middle where it lays out right to left.
    private var mirrors = false

    /// What a target the run names is told to beside the parameters: a composed control's own value worked out from it.
    private var named: ((Parameters) -> Void)?

    /// What every view's modifiers wrote on it.
    private var written = WrittenOnView()

    /// A layout of views, one per item, placed by `placements` on the host's frames.
    ///
    /// - Parameters:
    ///   - items: what to place, one view each.
    ///   - id: which part of an item is its identity - distinct across the items, and stable while the item means
    ///     the same view, so a view keeps its place and its state when the items change.
    ///   - parameters: the state the arithmetic is worked out from, which the program and the user's hand move.
    ///   - content: the view for one item.
    ///   - placements: where every view goes, given the room - from the layout's top left, at its size - and the
    ///     parameters as they stand this frame; one placement per view, in the items' order.
    public init<Content: View>(
        _ items: Items,
        id: KeyPath<Items.Element, ID>,
        parameters: Binding<Parameters>,
        @ViewBuilder content: @escaping (Items.Element) -> Content,
        placements: @escaping @MainActor (LayoutContext<ID>, Parameters) -> [Placement]
    ) {
        self.parameters = parameters
        source = Source(
            items: items, path: id, view: { content($0).node }, holder: { LayoutItemView(content: content($0)).node },
            arithmetic: { context, parameters, _ in placements(context, parameters) },
            readsFrom: false)
    }

    /// The same, for items that are their own identity.
    ///
    ///     MotionLayout(["Mural", "Ridge"], parameters: $turn) { Text($0) } placements: { context, _ in … }
    ///
    /// - Parameters:
    ///   - items: what to place, one view each.
    ///   - parameters: the state the arithmetic is worked out from.
    ///   - content: the view for one item.
    ///   - placements: where every view goes, given the room and the parameters.
    public init<Content: View>(
        _ items: Items,
        parameters: Binding<Parameters>,
        @ViewBuilder content: @escaping (Items.Element) -> Content,
        placements: @escaping @MainActor (LayoutContext<ID>, Parameters) -> [Placement]
    ) where Items.Element: Hashable, ID == Items.Element {
        self.init(items, id: \.self, parameters: parameters, content: content, placements: placements)
    }

    /// A layout whose arithmetic is handed, beside the parameters, where the run's motion set out: the parameters it
    /// stood at when the hand, a throw or a journey took it away, then each snap the run passes on an axis the hand
    /// moves.
    ///
    ///     MotionLayout(cards, id: \.name, parameters: $turn) { card in Face(card) } placements: { context, turn, segmentStart in
    ///         // The card that stood in front leaves the way the run goes - `turn` above `segmentStart` or below.
    ///     }
    ///
    /// The way the run goes is the parameters' side of the segment's start (`segmentStart` here); back past it, the
    /// run goes the other way from the same place, and at the start itself every view stands where it stood, so
    /// nothing drawn from it jumps.
    ///
    /// - Parameters:
    ///   - items: what to place, one view each.
    ///   - id: which part of an item is its identity.
    ///   - parameters: the state the arithmetic is worked out from.
    ///   - content: the view for one item.
    ///   - placements: where every view goes, given the room, the parameters as they stand this frame and those the
    ///     run's motion set out from; one placement per view, in the items' order.
    public init<Content: View>(
        _ items: Items,
        id: KeyPath<Items.Element, ID>,
        parameters: Binding<Parameters>,
        @ViewBuilder content: @escaping (Items.Element) -> Content,
        placements: @escaping @MainActor (LayoutContext<ID>, Parameters, Parameters) -> [Placement]
    ) {
        self.parameters = parameters
        source = Source(items: items, path: id, view: { content($0).node }, holder: { LayoutItemView(content: content($0)).node }, arithmetic: placements, readsFrom: true)
    }

    /// The same, for items that are their own identity.
    public init<Content: View>(
        _ items: Items,
        parameters: Binding<Parameters>,
        @ViewBuilder content: @escaping (Items.Element) -> Content,
        placements: @escaping @MainActor (LayoutContext<ID>, Parameters, Parameters) -> [Placement]
    ) where Items.Element: Hashable, ID == Items.Element {
        self.init(items, id: \.self, parameters: parameters, content: content, placements: placements)
    }

    /// How the layout maps one axis of the parameters: where its arithmetic is asked, and where its segments begin.
    ///
    ///     .axis(\.self, range: 0...2, keyframes: .every(1))
    ///     .axis(\.turn, range: 0...7, segments: .every(1), periodic: true)
    ///
    /// Given keyframes, the arithmetic is asked only there and at the range's ends, and the layout is blended
    /// between its answers along `interpolation(_:)`: quite different layouts, one at each keyframe, become one the
    /// value moves through. Past an end of a range that does not come round, the last two answers go on in a line.
    ///
    /// Given segments, the arithmetic taking `from` - where the motion set out - is handed the last segment the
    /// value passed, so a layout worked out from where a card started knows where that was.
    ///
    /// The mapping says nothing of the hand: what moves the axis, how far and where it rests is
    /// `interaction(_:)`'s, and the program writes the axis anywhere. An axis declared again takes the other's place.
    ///
    /// - Parameters:
    ///   - axis: the axis, one of the parameters' `axes`; `\.self` for `Double` parameters.
    ///   - range: how far the mapping runs.
    ///   - keyframes: where the arithmetic is asked beside the ends of the range; every frame unless said.
    ///   - segments: where a segment begins beside the ends of the range; none unless said.
    ///   - periodic: whether the range's end meets its start, the range one turn.
    /// - Returns: the layout, its axis mapped so.
    public func axis(
        _ axis: WritableKeyPath<Parameters, Double>,
        range: ClosedRange<Double>,
        keyframes: AxisValues? = nil,
        segments: AxisValues? = nil,
        periodic: Bool = false
    ) -> Self {
        var copy = self
        copy.mappings.removeAll { $0.axis == axis }
        copy.mappings.append(
            Mapping(axis: axis, range: range, keyframes: keyframes, segments: segments, periodic: periodic))
        return copy
    }

    /// What the user's hand and fingers move of the layout's parameters, and how.
    ///
    ///     .interaction(
    ///         .value($turn, axis: \.self, input: .swipe(.horizontal, unit: .frontItem))
    ///             .reversed(true)
    ///             .range(0...Double(cards.count - 1))
    ///             .snaps(.every(1)))
    ///
    /// The hand moves a value freely inside its range - less and less past an end, which it comes back onto when
    /// let go - and let go, the value goes on as its `release(_:)` says. Several values moved at once are
    /// `Interaction.simultaneous(_:)`: two moved one across and one down are a pan, and two fingers spreading and
    /// turning move theirs while the hand goes on with their middle. The views still answer a tap. An interaction
    /// said again takes the other's place.
    ///
    /// - Parameter interaction: the interaction, each value of it one of the layout's parameters; nil for none.
    /// - Returns: the layout, moved so by the hand.
    public func interaction(_ interaction: Interaction?) -> Self {
        var copy = self
        copy.declared = interaction
        return copy
    }

    /// The curve every view follows between the poses the arithmetic answers at the axes' keyframes: straight
    /// unless said.
    ///
    ///     .axis(\.self, range: 0...2, keyframes: .every(1))
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

    /// States the arithmetic reads beside the room and the parameters: a write to one runs it again on the host's
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

    /// Journeys the arithmetic samples beside the room and the parameters: a frame of one runs it again, and the
    /// views land where it says.
    ///
    ///     .following($tilt.journey)
    ///
    /// Following `$tilt` runs the arithmetic at a write of where the state is going; following `$tilt.journey`
    /// runs it at every frame of the way there. While the layout stands it is a consumer of each journey: the host
    /// carries the state for it though no property shows it, so `$tilt.journey.sample` answers in the arithmetic.
    ///
    /// - Parameters:
    ///   - first: a journey whose sample the arithmetic reads.
    ///   - more: any others.
    /// - Returns: the layout, following them.
    public func following<First: Walked, each More: Walked>(
        _ first: Journey<First>, _ more: repeat Journey<each More>
    ) -> Self {
        var copy = self
        copy.followed.append(first.storage.presentation)
        copy.consumed.append(JourneyConsumer(of: first))
        for journey in repeat each more {
            copy.followed.append(journey.storage.presentation)
            copy.consumed.append(JourneyConsumer(of: journey))
        }
        return copy
    }

    /// The layout's own size: what it takes of the room offered, worked out from its views and the parameters as they
    /// stand - a strip as tall as its tallest card, a board as wide as its columns.
    ///
    ///     .measure { context, _ in
    ///         let tallest = context.subviews.map { $0.sizeThatFits(LayoutProposal()).height }.max() ?? 0
    ///         return LayoutSize(width: context.proposal.width ?? 0, height: tallest)
    ///     }
    ///
    /// Without it the layout takes the room it is given. A stated `width` or `height` still bounds the answer. The
    /// closure measures and answers: it writes no state.
    ///
    /// - Parameter measure: the size, given the room offered, the views and the parameters.
    /// - Returns: the layout, with a size of its own.
    public func measure(
        _ measure: @escaping @MainActor (LayoutMeasurementContext<ID>, Parameters) -> LayoutSize
    ) -> Self {
        var copy = self
        copy.sized = measure
        return copy
    }

    /// What to draw over a placed view to darken it, at the opacity its placement answers as `shade`.
    ///
    ///     .shade {
    ///         Rectangle()
    ///             .fill(.black)
    ///             .cornerRadius(14)
    ///     }
    ///
    /// Give it the corners the views have. Where views overlap, a shade darkens a far view without showing the
    /// one behind it, as fading it would.
    ///
    /// - Parameter content: what to draw over each placed view.
    /// - Returns: the layout, shaded.
    public func shade<Content: View>(@ViewBuilder _ content: () -> Content) -> Self {
        shading(content().node)
    }

    /// The layout with `mask` drawn over each placed view.
    func shading(_ mask: Node) -> Self {
        var copy = self
        copy.mask = mask
        return copy
    }

    /// How every view of the layout comes onto the place the arithmetic gives it, unless the view says its own
    /// (`layoutBody(_:)`): a view a change moves - joining, the run arranged anew, let go by the hand - comes onto
    /// its new place as this body says.
    ///
    ///     .layoutBodies(.onChange(Spring(response: .milliseconds(420), damping: 0.8)))
    ///
    /// - Parameter body: the views' body; `.onChange()` unless said, `.none` for views standing at their places at
    ///   once - the parameters still travel under their state's motion.
    /// - Returns: the layout, its views moving as that body.
    public func layoutBodies(_ body: LayoutBody) -> Self {
        setValue(LayoutContract.layoutBodies, body)
    }

    /// Whether the layout follows the direction its language is read in, as a stack does: laid out right to left,
    /// it turns about its middle - each view's place, its move along and its turn - and the hand over it turns
    /// with it, so the arithmetic stays left to right.
    ///
    ///     MotionLayout(albums, id: \.title, parameters: $shown) { AlbumFace($0) } placements: { context, shown in … }
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

    /// Runs when the user activates a view - taps it, on the view drawn on top where the tap lands - with its item's
    /// identity, as a list's and a gallery's activation tells theirs.
    ///
    ///     .onItemActivated { id in open(id) }
    ///
    /// - Parameter handler: what to run, given the item's identity.
    /// - Returns: the layout, answering an activation.
    public func onItemActivated(_ handler: @escaping @MainActor (ID) throws -> Void) -> Self {
        var copy = self
        copy.activated.append(ValueHandler(step: handler))
        return copy
    }

    /// The same, with a handler that awaits: its `policy` says what an activation does while a run is under way.
    public func onItemActivated(policy: GatePolicy, _ handler: @escaping ValueEventHandler<ID>) -> Self {
        var copy = self
        copy.activated.append(ValueHandler(run: handler, gate: .own(policy)))
        return copy
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onItemActivated(gate: Gate, _ handler: @escaping ValueEventHandler<ID>) -> Self {
        var copy = self
        copy.activated.append(ValueHandler(run: handler, gate: .shared(gate)))
        return copy
    }

    /// Tells `handler` once the run comes to rest - no hand holding it, the parameters at its destination and every
    /// view at its place - with the parameters it rests at: the one event of rest, whatever moved it.
    ///
    ///     .onSettled { parameters in save(parameters) }
    public func onSettled(_ handler: @escaping @MainActor (Parameters) throws -> Void) -> Self {
        var copy = self
        copy.settled.append(ValueHandler(step: handler))
        return copy
    }

    /// The same, with a handler that awaits: its `policy` says what a rest does while a run is under way.
    public func onSettled(policy: GatePolicy, _ handler: @escaping ValueEventHandler<Parameters>) -> Self {
        var copy = self
        copy.settled.append(ValueHandler(run: handler, gate: .own(policy)))
        return copy
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onSettled(gate: Gate, _ handler: @escaping ValueEventHandler<Parameters>) -> Self {
        var copy = self
        copy.settled.append(ValueHandler(run: handler, gate: .shared(gate)))
        return copy
    }

    /// The hand takes one view by itself, rather than moving the run, when it begins as `start` says: the view drawn
    /// on top under the press follows the hand over the others, and let go goes back to its place under the layout's
    /// motion. A hand that begins any other way moves the run.
    ///
    ///     .itemDrag(begins: .longPress)
    ///
    /// - Parameter start: a first move across the layout's axis, or a press standing still a long press's time.
    /// - Returns: the layout, its views taken by the hand.
    public func itemDrag(begins start: ItemDragStart) -> Self {
        var copy = self
        copy.itemStart = start
        return copy
    }

    /// Runs as the hand takes a view by itself, each time it moves it, and each time it has stood still a long
    /// press's time more: the item's identity, where the hand is in the room, and how long it has stood still - an
    /// order changed as the hand crosses a slot moves the others, the held view staying under the hand.
    ///
    ///     .onItemDragged { drag in move(drag.id, to: slot(at: drag.at, in: drag.room)) }
    ///
    /// - Parameter handler: what to run, given the drag.
    /// - Returns: the layout, telling the drag.
    public func onItemDragged(_ handler: @escaping @MainActor (ItemDrag<ID>) throws -> Void) -> Self {
        var copy = self
        copy.dragged.append(ValueHandler(step: handler))
        return copy
    }

    /// The same, with a handler that awaits: its `policy` says what a move of the hand does while a run is under way.
    public func onItemDragged(policy: GatePolicy, _ handler: @escaping ValueEventHandler<ItemDrag<ID>>) -> Self {
        var copy = self
        copy.dragged.append(ValueHandler(run: handler, gate: .own(policy)))
        return copy
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onItemDragged(gate: Gate, _ handler: @escaping ValueEventHandler<ItemDrag<ID>>) -> Self {
        var copy = self
        copy.dragged.append(ValueHandler(run: handler, gate: .shared(gate)))
        return copy
    }

    /// A view the hand lets go of past `threshold` device units `directions` from where it took it - or thrown far
    /// enough that way - flies on out of the room, and `handler` runs with its item's identity once it has left: the
    /// application removes the item then. Let go short of it, the view goes back to its place. Written again, each
    /// one the view passed runs, in the order written.
    ///
    ///     .onItemDismissed(directions: .up, threshold: 120) { id in cards.removeAll { $0.id == id } }
    ///
    /// - Parameters:
    ///   - directions: the ways a view is dismissed.
    ///   - threshold: how far the hand takes it, in device units, before letting go dismisses it.
    ///   - handler: what to run, given the item's identity, once its view has left the room.
    /// - Returns: the layout, dismissing a view let go far enough.
    public func onItemDismissed(
        directions: SwipeDirections, threshold: Double, _ handler: @escaping @MainActor (ID) throws -> Void
    ) -> Self {
        var copy = self
        copy.dismissals.append(LayoutDismissal(directions: directions, threshold: threshold, handler: ValueHandler(step: handler)))
        return copy
    }

    /// The same, with a handler that awaits - an archive does: its `policy` says what another view dismissed does
    /// while a run is under way.
    ///
    ///     .onItemDismissed(directions: .up, threshold: 120, policy: .cancelPrevious) { id in try await archive(id) }
    public func onItemDismissed(
        directions: SwipeDirections, threshold: Double, policy: GatePolicy,
        _ handler: @escaping ValueEventHandler<ID>
    ) -> Self {
        var copy = self
        copy.dismissals.append(LayoutDismissal(
            directions: directions, threshold: threshold, handler: ValueHandler(run: handler, gate: .own(policy))))
        return copy
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onItemDismissed(
        directions: SwipeDirections, threshold: Double, gate: Gate,
        _ handler: @escaping ValueEventHandler<ID>
    ) -> Self {
        var copy = self
        copy.dismissals.append(LayoutDismissal(
            directions: directions, threshold: threshold, handler: ValueHandler(run: handler, gate: .shared(gate))))
        return copy
    }

    /// The same layout telling `handler` each target the run names, as it names it: what a composed control
    /// keeps a value of its own by - `GalleryView`'s position.
    func onNamed(_ handler: @escaping (Parameters) -> Void) -> Self {
        var copy = self
        copy.named = handler
        return copy
    }

    /// The views and the hand over them, each where the run puts it.
    public var body: some View {
        let run = self.run
        let mirrors = self.mirrors
        // A handler no longer written ends its runs now, as an element's does.
        dismissalRuns.keep(dismissals.count)
        settledRuns.keep(settled.count)
        dragRuns.keep(dragged.count)

        if Parameters.axes.isEmpty {
            complain("A MotionLayout's parameters name no axes: `axes` lists the numbers the hand and the program move.")
        }
        let worked = self.worked
        for complaint in worked.complaints { complain(complaint) }
        let definition = LayoutProgramDefinition(host: run.program())
        let moving = worked.moving.isEmpty ? nil : Interaction(standing: worked.moving)

        return PlacedStack {
            ForEach(run.slots, identify: { $0.identity }) { slot in run.wrapped(slot) }
        }
        .modified { element in
            element.describe(MotionLayoutContract.mirrorsRightToLeft, mirrors ? true : nil)
            // What a dismissal asked for ends with the layout.
            element.destroying.append { run.states.dismissals.orphan() }
            element.destroying.append { run.states.settles.orphan() }
            element.destroying.append { run.states.drags.orphan() }
            element.setProgram(MotionLayoutContract.layout, definition: definition)
            // The hand is heard on the element itself, over every view, which still answers a tap: what it moves is
            // the host's to hold, by this program.
            element.setProgram(MotionLayoutContract.interaction, definition: moving)
            element.describe(MotionLayoutContract.itemDrag, run.itemStart)
            if run.itemStart != nil {
                element.addHandler(MotionLayoutContract.itemDragUpdated) { gesture, at, velocity, still in
                    run.item(gesture, at: at.told, velocity: velocity.told, still: still.isFinite ? still : 0)
                }
            }
        }
        .setValue(MotionLayoutContract.parameters.token, on: run.parameters, mode: .inOut, kind: .property)
        // The program is worked out on the cycle whenever what it works from was written - the room the host said,
        // the parameters and their frames, a view in the hand - and the host reads the slots worked out.
        // Design: docs/design/core/layout-program.md#what-runs-it-again
        .engine([slot, run.parameters.followed, run.parameters.storage.presentation, $item.followed] + followed,
                consuming: consumed, priority: 0) { [slot] cycle in
            slot.measuring.begin()
            let answer = run.place(at: cycle.now, reducesMotion: cycle.reducesMotion)
            Renderer.shared.board.stirred.append(slot.number)
            return answer
        }
    }

    /// The body each view says it is (`layoutBody(_:)`), by its index: read off the view the first time a frame
    /// asks, and again after the view is built again - a state the view reads, a switch turning its body on, builds
    /// it again without the layout.
    /// Design: docs/design/views/motion-layout.md#bodies
    private final class Bodies {
        private let read: @MainActor (Int) -> LayoutBody?
        private var bodies: [Int: LayoutBody?] = [:]

        init(_ read: @escaping @MainActor (Int) -> LayoutBody?) {
            self.read = read
        }

        /// The body the view at `index` says it is; nil for one of the world's own.
        @MainActor
        func callAsFunction(_ index: Int) -> LayoutBody? {
            if let body = bodies[index] { return body }
            let body = read(index)
            bodies[index] = .some(body)
            return body
        }

        /// The view at `index` was built again: its body is read anew the next time a frame asks.
        func rebuilt(_ index: Int) {
            bodies[index] = nil
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

        /// Where every view goes, given the room and the views, the parameters and where its motion set out.
        let arithmetic: @MainActor (LayoutContext<ID>, Parameters, Parameters) -> [Placement]

        /// Which description this is: the next number at each, never one again - an object's address is, once it
        /// is let go.
        let number: Int

        /// Whether the arithmetic is handed where the motion set out, and the poses it answered at keyframes, kept
        /// while this description stands.
        let readsFrom: Bool
        let kept = LayoutPoses()

        /// What the initializer was handed.
        @MainActor
        init(
            items: Items,
            path: KeyPath<Items.Element, ID>,
            view: @escaping (Items.Element) -> Node,
            holder: @escaping (Items.Element) -> Node,
            arithmetic: @escaping @MainActor (LayoutContext<ID>, Parameters, Parameters) -> [Placement],
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
        let hands = worked.hands
        let identities = numbers.numbered(items.map { AnyHashable($0[keyPath: path]) })
        let subviews = LayoutSubviews(items.map { $0[keyPath: path] }, measuring: slot.measuring)
        var sizing: (@MainActor (Double?, Double?, Parameters) -> LayoutSize)?
        if let sized {
            sizing = { width, height, parameters in
                let context = LayoutMeasurementContext(
                    proposal: LayoutProposal(width: width, height: height), subviews: subviews)
                return Self.held(sized(context, parameters))
            }
        }
        let bodies = Bodies { [items, view = source.view] index in
            guard items.indices.contains(index) else { return nil }
            return view(items[index]).props[ViewContract.layoutBody.token].flatMap(LayoutBody.init(propValue:))
        }

        return Run(
            items: items,
            slots: zip(items, identities).enumerated().map { offset, item in
                Slot(identity: item.1, index: offset, item: item.0)
            },
            make: source.view,
            holder: source.holder,
            arithmetic: { [arithmetic = source.arithmetic, subviews] room, parameters, from in
                arithmetic(LayoutContext(bounds: room, subviews: subviews), parameters, from)
            },
            curve: curve ?? LayoutCurve.linear,
            readsFrom: source.readsFrom,
            kept: source.kept,
            followed: followed,
            description: source.number,
            mask: mask,
            path: path,
            activated: activated,
            named: named,
            itemStart: itemStart,
            dragged: dragged,
            dismissals: dismissals,
            parameters: parameters,
            states: States(
                slot: slot, room: _room, shown: _shown, from: _from, item: _item, dismissals: dismissalRuns,
                settles: settledRuns, drags: dragRuns),
            hands: hands,
            focus: hands.first { $0.way != nil },
            viewsBody: written.value(LayoutContract.layoutBodies.token).flatMap(LayoutBody.init(propValue:)) ?? .onChange(),
            body: { [bodies] index in bodies(index) },
            rebuilt: { [bodies] index in bodies.rebuilt(index) },
            settled: settled,
            sized: sizing)
    }

    /// A size the layout said for itself, held to a size: a side that is no number, or below nought, is nought,
    /// said once.
    /// Design: docs/design/views/motion-layout.md#a-size-of-its-own
    private static func held(_ answered: LayoutSize) -> LayoutSize {
        let side = { (side: Double) in side.isFinite ? max(0, side) : 0 }
        if !answered.width.isFinite || !answered.height.isFinite || answered.width < 0 || answered.height < 0 {
            complain("A MotionLayout's measure answered a size that is none - a side below nought, or no number: "
                + "that side is nought.")
        }
        return LayoutSize(width: side(answered.width), height: side(answered.height))
    }

    /// The layout's states, handed on whole: what its engine and handlers read and write.
    struct States {
        let slot: LayoutProgramSlot
        let room: State<Rect>
        let shown: State<LayoutShown<Parameters>>
        let from: State<Parameters?>
        let item: State<LayoutItemHand?>
        let dismissals: EventRegistration
        let settles: EventRegistration
        let drags: EventRegistration
    }
}

extension MotionLayout {
    /// What every view's modifiers give back: the layout itself, so its own modifiers come after any of theirs.
    public typealias Modified = Self

    /// The placeholder its body is built under, with what every view's modifiers wrote on it. Assigning to it does
    /// nothing.
    public var node: Node {
        get { written.node(of: self) }
        set {}
    }

    /// A copy with one more modifier written on it.
    public func modified(_ change: (inout Node) -> Void) -> Self {
        var copy = self
        copy.written.write(change, on: Self.self)
        return copy
    }
}

extension MotionLayout: WalkedView {
    /// The parts the walk reads, as a mirror would list them, with no mirror made: a mirror of a generic type works
    /// its fields' types out at every reading, and every render of a layout walks its engine
    /// (`MotionLayoutTests.testTheEngineNamesEveryPartAMirrorWould` holds the list to the fields).
    var walkedParts: [(label: String, value: Any)] {
        [
            ("_item", _item),
            ("_slot", _slot), ("_shown", _shown), ("_from", _from), ("_room", _room), ("_numbers", _numbers),
            ("_dismissalRuns", _dismissalRuns), ("_settledRuns", _settledRuns), ("_dragRuns", _dragRuns),
            ("source", source), ("parameters", parameters), ("mappings", mappings), ("declared", declared as Any), ("curve", curve as Any),
            ("followed", followed), ("consumed", consumed), ("mask", mask as Any), ("activated", activated),
            ("itemStart", itemStart as Any), ("dragged", dragged), ("dismissals", dismissals),
            ("settled", settled), ("sized", sized as Any),
            ("mirrors", mirrors),
            ("named", named as Any), ("written", written),
        ]
    }
}

/// How many descriptions of motion layouts have been made.
@MainActor private var descriptionsMade = 0

/// What a layout last showed - the description it came from, at what parameters, set out from where and in what room,
/// each view's pose and where it was shown, by identity - and the changes on their way to the poses: what a new
/// description is measured against.
struct LayoutShown<Parameters: LayoutParameters>: Equatable {
    var description: Int?
    var parameters: Parameters?
    var from: Parameters?
    var room = Rect.zero
    var poses: [Int: Placement] = [:]

    /// Where the parameters were going when whoever keeps a value by them was last told; nil before the first frame.
    var named: Parameters?

    /// Whether the run stood at rest the last frame.
    var resting = true
}

private extension Point {
    /// The point a host told, each coordinate that is no finite number nought.
    var told: Point { Point(x.isFinite ? x : 0, y.isFinite ? y : 0) }
}
