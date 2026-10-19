// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// Where a scroller stands as its host knows it, the same on every host: an offset the tree writes - moved to at once
/// where the scroller was laid out or scrolls neither way, else kept for its first layout - and what its toolkit says
/// it moved to, told apart as the user's move or the program's own arriving.
/// Design: docs/design/host/layout.md#where-a-scroller-stands
@_spi(Host) @MainActor public struct ScrollerOffset {
    /// Where the scroller stands, as last told or heard.
    public private(set) var standing = Point(x: 0, y: 0)

    /// Where the program moved the scroller, until its toolkit says it stands there, and where it stood before.
    private var arriving: (at: Point, from: Point)?

    /// The offset written before the first layout, waiting for it.
    private var waiting: Point?
    private var laidOut = false

    /// A scroller at its origin, not laid out yet.
    public init() {}

    /// The tree wrote `offset` for a scroller along `orientation`: where to move it now; nil where it asks nothing,
    /// or waits for the first layout.
    public mutating func written(_ offset: Point?, orientation: ScrollOrientation) -> Point? {
        // Before the first layout the last offset written waits, one back where the scroller stands as nothing.
        if !laidOut, orientation != .neither, let offset, offset.x.isFinite, offset.y.isFinite {
            waiting = ScrollArithmetic.differs(offset, standing) ? offset : nil
            return nil
        }
        guard let target = ScrollArithmetic.offsetWritten(offset, standing: standing, orientation: orientation) else {
            return nil
        }
        guard laidOut || orientation == .neither else {
            waiting = target
            return nil
        }
        return target
    }

    /// The scroller is laid out: the offset written before its first layout, where one waits, to move to now.
    public mutating func laidOutNow() -> Point? {
        laidOut = true
        defer { waiting = nil }
        return waiting
    }

    /// The program moves the scroller to `target`, kept within its reach: whether its toolkit is to move it at all -
    /// not where it stands within half a point already. What the toolkit says of it, inside the program's write or
    /// later within half a point of `target`, is the move arriving.
    public mutating func programMoves(to target: Point) -> Bool {
        guard ScrollArithmetic.differs(target, standing) else { return false }
        arriving = (target, standing)
        standing = target
        return true
    }

    /// The toolkit stopped the program's move at `stop`, as read once it was asked - a toolkit keeping a move within
    /// what it reaches itself: its word still to come is to say `stop`.
    public mutating func programLanded(at stop: Point) {
        standing = stop
        guard let from = arriving?.from else { return }
        arriving = ScrollArithmetic.differs(stop, from) ? (stop, from) : nil
    }

    /// The toolkit says the scroller stands at `now`: the user's move, from where it stood; nil for the program's
    /// own move arriving - said inside the program's write, or within half a point of where the program moved it -
    /// or for no move at all.
    public mutating func toolkitMoved(to now: Point) -> (from: Point, to: Point)? {
        if ProgramWrite.isWriting || arriving.map({ !ScrollArithmetic.differs($0.at, now) }) == true {
            arriving = nil
            standing = now
            return nil
        }
        guard now != standing else { return nil }
        let from = standing
        standing = now
        return (from, now)
    }

    /// The user took hold of the scroller: a move of the program's still on its way is theirs from now.
    public mutating func userTookHold() {
        arriving = nil
    }
}
