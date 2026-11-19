// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Design: docs/design/core/layout-program.md#the-program

/// A layout's arithmetic as the host meets it: the host says the room it laid the layout out in, and reads where
/// every child stands whenever the cycle says the layout's slot was worked out again. It crosses in the patch as it
/// is, typed, in one process - by reference, so a patch carrying one is no larger for it.
@_spi(Host) public final class HostLayoutProgram: Sendable {
    /// Which layout's program this is: the same number while the layout stands.
    public let slot: UInt64

    /// Which description of the layout made it: another at every build of the layout.
    public let revision: UInt64

    /// Says the room the host laid the layout out in, `width` by `height` points: a room that changed is worked out
    /// in the next cycle.
    public let layOut: @MainActor (_ width: Double, _ height: Double) -> Void

    /// Where each child stands, in the children's order, as the program last worked it out; none while the room is
    /// not measured.
    public let placed: @MainActor () -> [HostPlacement]

    /// The run the places were made of, as the layout wrote it: what the core's own tests read.
    let run: (@MainActor () -> PlacedRun)?

    /// A program of the layout `slot` names, made by its description numbered `revision`.
    public convenience init(
        slot: UInt64, revision: UInt64, layOut: @escaping @MainActor (Double, Double) -> Void,
        placed: @escaping @MainActor () -> [HostPlacement]
    ) {
        self.init(slot: slot, revision: revision, layOut: layOut, placed: placed, run: nil)
    }

    /// A program whose places are made of `run`.
    init(
        slot: UInt64, revision: UInt64, layOut: @escaping @MainActor (Double, Double) -> Void,
        placed: @escaping @MainActor () -> [HostPlacement], run: (@MainActor () -> PlacedRun)?
    ) {
        self.slot = slot
        self.revision = revision
        self.layOut = layOut
        self.placed = placed
        self.run = run
    }
}

/// How a patch changes an element's layout program.
@_spi(Host) public enum HostLayoutUpdate: Sendable {
    /// The program the element runs from now on.
    case replace(HostLayoutProgram)

    /// The element runs none.
    case clear
}
