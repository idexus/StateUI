// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A layout's slot, the same while the layout stands: the number its program crosses under, the stamp a new room
/// moves, and where the run last put every child.
/// Design: docs/design/core/layout-program.md#the-program
@MainActor
final class LayoutProgramSlot: FollowedState {
    let number: UInt64

    /// Where the run last put every child, in the children's order.
    var placed = PlacedRun()

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

    /// The program the host is handed for the description numbered `revision`: `keep` takes the room it says, and
    /// a room that changed asks for a cycle.
    func program(revision: UInt64, keep: @escaping @MainActor (Double, Double) -> Void) -> HostLayoutProgram {
        HostLayoutProgram(
            slot: number, revision: revision,
            layOut: { [self] width, height in
                guard said?.width != width || said?.height != height else { return }
                said = (width, height)
                keep(width, height)
                stamp &+= 1
                UIThreadExecutor.shared.askForTurn()
            },
            placed: { [self] in HostBoundary.placements(of: placed) },
            run: { [self] in placed })
    }
}
