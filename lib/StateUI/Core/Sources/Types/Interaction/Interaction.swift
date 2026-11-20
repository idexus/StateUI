// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What the user's hand moves on a view, and how: a declaration the view reads where it is written.
///
///     .interaction(
///         .value($turn, axis: \.self, input: .translation(.horizontal, unit: .frontItem))
///             .reversed(true)
///             .range(0...6)
///             .snaps(.every(1))
///             .release(.projected(.spring(Spring(response: .milliseconds(500), damping: 0.8)))))
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

    /// The hand moving one number of a state: the state's value follows the hand while it holds it, and goes on as
    /// `release(_:)` says once it lets go.
    ///
    ///     .value($table, axis: \.zoom, input: .magnification).range(0.5...2)
    ///
    /// - Parameters:
    ///   - state: the state moved - a motion layout's parameters.
    ///   - axis: the number of it the input moves, one of its `axes`; `\.self` for a `Double`.
    ///   - input: what of the hand moves it.
    /// - Returns: the interaction.
    public static func value<Parameters: LayoutParameters>(
        _ state: Binding<Parameters>, axis: WritableKeyPath<Parameters, Double>, input: InteractionInput
    ) -> Interaction {
        let storage = state.storage
        let leaf = Leaf(
            state: ObjectIdentifier(storage), image: { storage.carryAsJourney() }, axis: axis,
            lane: Parameters.axes.firstIndex(of: axis), input: input)
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
