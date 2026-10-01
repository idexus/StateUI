// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// An offset the tree writes to a scroller, the same on every host: moved to at once where the scroller was laid out
/// or scrolls neither way, else kept for its first layout - the last one written waiting.
/// Design: docs/design/host/layout.md#an-offset-the-tree-writes
@_spi(Host) public struct WrittenScrollOffset: Sendable {
    private var waiting: Point?
    private var laidOut = false

    /// A scroller not laid out yet.
    public init() {}

    /// The tree wrote `offset` for a scroller standing at `standing` along `orientation`: where to move it now; nil
    /// where it asks nothing, or waits for the first layout.
    public mutating func written(_ offset: Point?, standing: Point, orientation: ScrollOrientation) -> Point? {
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
}
