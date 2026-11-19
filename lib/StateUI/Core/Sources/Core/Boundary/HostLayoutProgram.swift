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

    /// Says how the host measures a child of the layout, and - said again - that a child may measure otherwise than
    /// it did: a layout whose arithmetic measured a child is worked out again in the next cycle.
    public let measuredBy: @MainActor (@escaping HostChildMeasure) -> Void

    /// The layout's own size in a room offered - a width, a height, either or neither; nil where the layout says
    /// none and takes the room it is given.
    public let measure: (@MainActor (_ width: Double?, _ height: Double?) -> LayoutSize)?

    /// The run the places were made of, as the layout wrote it: what the core's own tests read.
    let run: (@MainActor () -> PlacedRun)?

    /// A program of the layout `slot` names, made by its description numbered `revision`.
    public convenience init(
        slot: UInt64, revision: UInt64, layOut: @escaping @MainActor (Double, Double) -> Void,
        placed: @escaping @MainActor () -> [HostPlacement]
    ) {
        self.init(
            slot: slot, revision: revision, layOut: layOut, placed: placed, measuredBy: { _ in }, measure: nil, run: nil)
    }

    /// A program whose places are made of `run`, measuring through what `measuredBy` is told.
    init(
        slot: UInt64, revision: UInt64, layOut: @escaping @MainActor (Double, Double) -> Void,
        placed: @escaping @MainActor () -> [HostPlacement],
        measuredBy: @escaping @MainActor (@escaping HostChildMeasure) -> Void,
        measure: (@MainActor (Double?, Double?) -> LayoutSize)?, run: (@MainActor () -> PlacedRun)?
    ) {
        self.slot = slot
        self.revision = revision
        self.layOut = layOut
        self.placed = placed
        self.measuredBy = measuredBy
        self.measure = measure
        self.run = run
    }
}

/// How a host measures one child of a layout: its place among the children, the width and the height offered - nil
/// for none - and the child's answer.
@_spi(Host) public typealias HostChildMeasure = @MainActor (_ child: Int, _ width: Double?, _ height: Double?)
    -> HostChildMeasured

/// A child's answer to a room offered: its size, and where its first line of words rests.
@_spi(Host) public struct HostChildMeasured: Equatable, Sendable {
    /// The child's size, its stated sizes and bounds applied and its margin left out.
    public var size: LayoutSize

    /// How far below its top its first line of words rests; nil for a child with no words.
    public var firstBaseline: Double?

    /// A child `size` large, its words resting at `firstBaseline`.
    public init(size: LayoutSize, firstBaseline: Double?) {
        self.size = size
        self.firstBaseline = firstBaseline
    }
}

/// How a patch changes an element's layout program.
@_spi(Host) public enum HostLayoutUpdate: Sendable {
    /// The program the element runs from now on.
    case replace(HostLayoutProgram)

    /// The element runs none.
    case clear
}
