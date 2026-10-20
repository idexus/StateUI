// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One view of a layout the hand holds by itself: which, as it was shown when the hand took it, where the hand took
/// it and where the hand is now, in the room; let go, how fast the hand went, per second, whether that dismisses it,
/// when it set out flying and whether it has left the room.
struct LayoutItemHand: Equatable {
    let identity: Int
    let taken: Placement
    let from: Point
    var at: Point
    var speed: Point?
    var dismissed = false
    var flew: Double?
    var gone = false

    /// The view held where the hand is: its look as `shown` - its place's, with any change on its way - its middle
    /// where the middle it was taken by has moved with the hand, over every view of `run`.
    func held(_ shown: Placement, over run: [Placement]) -> Placement {
        var placement = shown
        placement.bounds.x = taken.bounds.x + taken.bounds.width / 2 + at.x - from.x - shown.bounds.width / 2
        placement.bounds.y = taken.bounds.y + taken.bounds.height / 2 + at.y - from.y - shown.bounds.height / 2
        placement.zIndex = (run.map(\.zIndex).max() ?? 0) + 1
        return placement
    }
}
