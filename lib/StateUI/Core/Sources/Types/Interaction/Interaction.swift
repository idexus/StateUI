// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What the user's hand moves on a view, and how: a declaration the view reads where it is written.
///
///     .interaction(
///         .value($turn, input: .translation(.horizontal, unit: .frontItem))
///             .reversed(true)
///             .range(0...6)
///             .snaps(.every(1))
///             .release(.projected(.spring(response: .milliseconds(500), damping: 0.8))))
///
/// An interaction is a value: each of its methods answers a copy, and nothing is recognized, reserved or timed
/// until a view wearing it stands. One `.interaction(_:)` says the whole of it - several values moved at once are
/// `simultaneous(_:)`.
/// Design: docs/design/views/interaction.md#one-declaration
@MainActor
public struct Interaction {
    /// One value an input moves: the state it is a number of - its identity, and the image the host carries it
    /// on - the number, by its key path and its place among the state's numbers, what moves it, how far the hand
    /// may take it, where it may rest, whether it comes round, which way it grows, how it goes on let go and what
    /// a write of the program does to it under the hand.
    struct Leaf {
        let state: ObjectIdentifier
        let image: @MainActor () -> HostStorage?
        let consumer: JourneyConsumer
        let axis: AnyKeyPath
        let lane: Int?
        let input: InteractionInput
        var range: ClosedRange<Double>?
        var snaps: AxisValues?
        var periodic = false
        var reversed = false
        var release = InteractionRelease.standard
        var programWrites = InteractionProgramWrites.interrupt
    }

    /// The values moved, in written order.
    var leaves: [Leaf]

    /// Whether the interaction is several at once.
    private let isSet: Bool

    /// What was written on it that does not stand, as the author is told it.
    var refused: [String] = []

    /// The hand moving a state that is one number: the state's value follows the hand while it holds it, and goes on
    /// as `release(_:)` says once it lets go.
    ///
    ///     .value($offset, input: .translation(.horizontal)).range(0...240)
    ///
    /// - Parameters:
    ///   - state: the state moved.
    ///   - input: what of the hand moves it.
    /// - Returns: the interaction.
    public static func value(_ state: Binding<Double>, input: InteractionInput) -> Interaction {
        value(state, axis: \.self, input: input)
    }

    /// The hand moving one number of a state of several: that number follows the hand while it holds it, and goes
    /// on as `release(_:)` says once it lets go.
    ///
    ///     .value($table, axis: \.zoom, input: .magnification).range(0.5...2)
    ///
    /// - Parameters:
    ///   - state: the state moved, a `LayoutParameters` of several numbers.
    ///   - axis: the number of it the input moves, one of its `axes`.
    ///   - input: what of the hand moves it.
    /// - Returns: the interaction.
    public static func value<Parameters: LayoutParameters>(
        _ state: Binding<Parameters>, axis: WritableKeyPath<Parameters, Double>, input: InteractionInput
    ) -> Interaction {
        let storage = state.storage
        let leaf = Leaf(
            state: ObjectIdentifier(storage), image: { storage.carryAsJourney() },
            consumer: JourneyConsumer(of: state.journey), axis: axis, lane: Parameters.axes.firstIndex(of: axis),
            input: input)
        return Interaction(leaves: [leaf], isSet: false, refused: input.complaint.map { [$0] } ?? [])
    }

    /// Several values moved at once: one hand moving two numbers a pan, two fingers spreading and turning, each
    /// number by its own input. No two of them move the same number.
    ///
    ///     .simultaneous([
    ///         .value($table, axis: \.x, input: .translation(.horizontal, unit: .frontItem)).range(0...2),
    ///         .value($table, axis: \.zoom, input: .magnification).range(0.45...1),
    ///     ])
    ///
    /// - Parameter interactions: the interactions, each as it would stand alone.
    /// - Returns: the interaction of them all.
    public static func simultaneous(_ interactions: [Interaction]) -> Interaction {
        Interaction(
            leaves: interactions.flatMap(\.leaves), isSet: true, refused: interactions.flatMap(\.refused))
    }

    /// How far the hand may take the value: it moves freely inside the range, less and less past an end, and comes
    /// back onto it let go. The program writes the value anywhere - the range is the hand's.
    ///
    /// - Parameter range: the range; above nought for a magnification.
    /// - Returns: the interaction, its value kept there.
    public func range(_ range: ClosedRange<Double>) -> Interaction {
        each("range") { $0.range = range }
    }

    /// Where the value may come to rest: let go, it comes onto the snap nearest where it would end. Given a range,
    /// its ends are snaps too.
    ///
    /// - Parameter values: the snaps - `.every(1)`, `[1, 2]`, `.endpoints`; nil for anywhere in the range.
    /// - Returns: the interaction, its value resting there.
    public func snaps(_ values: AxisValues?) -> Interaction {
        each("snaps") { $0.snaps = values }
    }

    /// Whether the value comes round: its range one turn, its end meeting its start, so the hand moves it on for
    /// ever.
    ///
    /// - Parameter enabled: true for a value that comes round; it needs a range of some length.
    /// - Returns: the interaction.
    public func periodic(_ enabled: Bool) -> Interaction {
        each("periodic") { $0.periodic = enabled }
    }

    /// Which way the value grows under the hand: as it moves right or down, and as the fingers turn clockwise,
    /// unless reversed - a row of cards whose growing number moves them left says true.
    ///
    /// - Parameter enabled: true for a value growing as the hand moves left or up, or the fingers turn the other way.
    /// - Returns: the interaction.
    public func reversed(_ enabled: Bool) -> Interaction {
        each("reversed") { $0.reversed = enabled }
    }

    /// How the value goes on once the hand lets go. Said of several at once, every one of them goes on so.
    ///
    /// - Parameter release: `.projected(_:)` thrown on, `.nearest(_:)` onto the nearest, `.stay` where it was left.
    /// - Returns: the interaction, let go that way.
    public func release(_ release: InteractionRelease) -> Interaction {
        var copy = self
        for index in copy.leaves.indices { copy.leaves[index].release = release }
        return copy
    }

    /// What a write of the program does to the value while the hand holds it. Said of several at once, it is every
    /// one's.
    ///
    /// - Parameter policy: `.interrupt`, the write taking the value from the hand, unless said; `.deferLatest`, the
    ///   hand keeping it and the value going where the program sent it last once let go.
    /// - Returns: the interaction, meeting a write so.
    public func programWrites(_ policy: InteractionProgramWrites) -> Interaction {
        var copy = self
        for index in copy.leaves.indices { copy.leaves[index].programWrites = policy }
        return copy
    }

    /// The interaction with `change` made to its one value; said of several at once, `name` is refused - each value
    /// has its own.
    private func each(_ name: String, _ change: (inout Leaf) -> Void) -> Interaction {
        var copy = self
        guard !isSet, !copy.leaves.isEmpty else {
            copy.refused.append(
                "An interaction of several values at once was given `\(name)`, which each value says for itself. "
                    + "It is left out.")
            return copy
        }
        change(&copy.leaves[0])
        return copy
    }
}

extension Interaction {
    /// The interaction of `leaves` alone: what a view reading it found to stand.
    init(standing leaves: [Leaf]) {
        self.init(leaves: leaves, isSet: true)
    }

    /// The values that stand on a view - one that measures a front view, where `measuresFront` - and what is wrong
    /// with the others, as the author is told it: a declaration that does not stand moves nothing.
    /// Design: docs/design/views/interaction.md#what-is-refused
    func standing(measuresFront: Bool) -> (leaves: [Leaf], complaints: [String]) {
        var complaints = refused
        // Two moving one number are refused together: neither is the one the author meant.
        var moved: [Number: Int] = [:]
        for leaf in leaves { if let lane = leaf.lane { moved[Number(state: leaf.state, lane: lane), default: 0] += 1 } }
        if moved.values.contains(where: { $0 > 1 }) {
            complaints.append("An interaction moves one number twice. The hand moves nothing of it.")
        }
        let standing = leaves.filter { leaf in
            guard let lane = leaf.lane else {
                complaints.append(
                    "An interaction moves a number its state's `axes` do not list. The hand moves nothing of it.")
                return false
            }
            if moved[Number(state: leaf.state, lane: lane)] ?? 0 > 1 { return false }
            if let complaint = Self.complaint(of: leaf, measuresFront: measuresFront) {
                complaints.append(complaint)
                return false
            }
            return true
        }
        return (standing, complaints)
    }

    /// One number of a state, which one value alone may move.
    private struct Number: Hashable {
        let state: ObjectIdentifier
        let lane: Int
    }

    /// What is wrong with one value, if anything, as the author is told it.
    private static func complaint(of leaf: Leaf, measuresFront: Bool) -> String? {
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
        if case .hand(_, .front, _) = leaf.input.gesture, !measuresFront {
            return "An interaction's unit is the view in front, and its view runs no layout that draws one: say "
                + "`.points(_:)` or `.containerLength`. The hand moves nothing of it."
        }
        return nil
    }

    /// The states the values move, each a consumer of its channel while the view stands.
    var consumers: [JourneyConsumer] { leaves.map(\.consumer) }

    /// The interaction as the host is handed it, each state by the number `numbered` gives its image: a value whose
    /// state the host carries as no journey, or that is no number of its state, moves nothing.
    /// Design: docs/design/views/interaction.md#what-the-host-is-handed
    func program(numbered: (HostStorage) -> Int32) -> HostInteractionProgram {
        HostInteractionProgram(values: leaves.compactMap { leaf in
            guard let lane = leaf.lane, let image = leaf.image() else { return nil }

            let input: HostInteractionInput
            switch leaf.input.gesture {
            case .hand(let way, let travel, let swipes):
                let unit: InteractionUnit = switch travel {
                case .length(let points): .points(points)
                case .front: .frontItem
                case .room: .containerLength
                }
                input = .translation(way, unit: unit, swipes: swipes)
            case .magnification:
                input = .magnification
            case .rotation(let degrees):
                input = .rotation(degreesPerUnit: degrees)
            }
            let snaps: HostInteractionSnaps? = leaf.snaps.flatMap { snaps in
                leaf.range.map { .at(snaps.values(in: $0, periodic: leaf.periodic)) } ?? snaps.unbounded
            }
            return HostInteractionValue(
                state: numbered(image), lane: lane, input: input,
                low: leaf.range?.lowerBound ?? -.infinity, high: leaf.range?.upperBound ?? .infinity,
                snaps: snaps, periodic: leaf.periodic, reversed: leaf.reversed, release: leaf.release,
                programWrites: leaf.programWrites)
        })
    }
}
