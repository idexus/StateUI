// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A layout's slot, the same while the layout stands: the number its program crosses under, and the stamp a new
/// room or a measure said again moves.
/// Design: docs/design/core/layout-program.md#the-program
@MainActor
final class LayoutProgramSlot: FollowedState {
    let number: UInt64

    /// What the layout's views measure as, kept while its arithmetic asked.
    let measuring = LayoutMeasuring()

    /// How many rooms the host has said: what the run follows to be worked out again.
    private(set) var stamp = 0

    /// The room the host said last.
    private var said: (width: Double, height: Double)?

    /// How many programs the slot handed: each build of the layout its own.
    private var built: UInt64 = 0

    var reports: Int { 0 }

    private static var made: UInt64 = 0

    init() {
        Self.made += 1
        number = Self.made
    }

    /// The program the host is handed for one build of the layout, numbered anew: `keep` takes the room it says,
    /// a room that changed - or a measure said again to a layout that measured - asks for a cycle, and `measure`
    /// answers the layout's own size.
    func program(
        measure: (@MainActor (Double?, Double?) -> LayoutSize)?,
        frontItemUnit: (@MainActor (Int, Double, Bool, [Double]?) -> Double?)? = nil,
        answered: @escaping @MainActor () -> HostLayoutAnswer = { HostLayoutAnswer() },
        run: (@MainActor () -> PlacedRun)? = nil,
        place: (@MainActor ([Double], [Double], Double, Double) -> HostLayoutAnswer)? = nil,
        axes: [HostLayoutAxis] = [], keep: @escaping @MainActor (Double, Double) -> Void
    ) -> HostLayoutProgram {
        built &+= 1
        return HostLayoutProgram(
            slot: number, revision: built,
            layOut: { [self] width, height in
                guard said?.width != width || said?.height != height else { return }
                said = (width, height)
                keep(width, height)
                stamp &+= 1
                UIThreadExecutor.shared.askForTurn()
            },
            answered: answered,
            frontItemUnit: frontItemUnit,
            place: place,
            axes: axes,
            measuredBy: { [self] measure in
                measuring.measure = measure
                // A layout that measured no view stands as it stood, however its views measure.
                guard measuring.forget() else { return }
                stamp &+= 1
                UIThreadExecutor.shared.askForTurn()
            },
            measure: measure, run: run)
    }
}
