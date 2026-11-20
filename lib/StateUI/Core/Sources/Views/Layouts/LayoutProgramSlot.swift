// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A layout's slot, the same while the layout stands: the number its program crosses under, the stamp a new room
/// moves, and where the run last put every child.
/// Design: docs/design/core/layout-program.md#the-program
@MainActor
final class LayoutProgramSlot: FollowedState {
    let number: UInt64

    /// Where the run last put every child, in the children's order: its place, or where the hand holds it.
    var placed = PlacedRun()

    /// What the host is answered: the places, and what brings each child onto its own.
    var answer = HostLayoutAnswer()

    /// The last change of the layout: its number, where it measures each view's way to, by the view's identity, and
    /// how fast a view the hand let go sets out. Kept until the next, so a host that reads late still hears it.
    private(set) var changes: UInt64 = 0
    private(set) var discrete: [Int: Placement] = [:]
    private(set) var released: [Int: Point] = [:]

    /// Whether a child is still on its way to its place: the layout's own word at a change, the host's from then.
    private(set) var bodiesMove = false

    /// Whether a hand holds a number of the layout's parameters, as the host says.
    private(set) var handHolds = false

    /// A change of the layout: `discrete` and `released` are its own, and its views are on their way until the
    /// host says they rest.
    func changed(_ discrete: [Int: Placement], released: [Int: Point]) {
        changes &+= 1
        self.discrete = discrete
        self.released = released
        bodiesMove = true
    }

    /// What measures the layout's views for its arithmetic.
    let measuring = LayoutMeasuring()

    /// How many rooms the host has said: what the run follows to be worked out again.
    private(set) var stamp = 0

    /// The room the host said last.
    private var said: (width: Double, height: Double)?

    var reports: Int { 0 }

    private static var made: UInt64 = 0

    init() {
        Self.made += 1
        number = Self.made
    }

    /// The program the host is handed for the description numbered `revision`: `keep` takes the room it says, a
    /// room that changed - or a measure said again to a layout that measured - asks for a cycle, and `measure`
    /// answers the layout's own size.
    func program(
        revision: UInt64, measure: (@MainActor (Double?, Double?) -> LayoutSize)?,
        frontItemUnit: (@MainActor (Int, Double, Bool, Bool) -> Double?)? = nil,
        keep: @escaping @MainActor (Double, Double) -> Void
    ) -> HostLayoutProgram {
        HostLayoutProgram(
            slot: number, revision: revision,
            layOut: { [self] width, height in
                guard said?.width != width || said?.height != height else { return }
                said = (width, height)
                keep(width, height)
                stamp &+= 1
                UIThreadExecutor.shared.askForTurn()
            },
            answered: { [self] in answer },
            bodiesMove: { [self] moving in
                guard moving != bodiesMove else { return }
                bodiesMove = moving
                stamp &+= 1
                UIThreadExecutor.shared.askForTurn()
            },
            handHolds: { [self] holding in
                guard holding != handHolds else { return }
                handHolds = holding
                stamp &+= 1
                UIThreadExecutor.shared.askForTurn()
            },
            frontItemUnit: frontItemUnit,
            measuredBy: { [self] measure in
                measuring.measure = measure
                // A layout that measured no view stands as it stood, however its views measure.
                guard measuring.forget() else { return }
                stamp &+= 1
                UIThreadExecutor.shared.askForTurn()
            },
            measure: measure,
            run: { [self] in placed })
    }
}
