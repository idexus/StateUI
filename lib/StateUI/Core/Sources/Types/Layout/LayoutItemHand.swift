// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One view of a layout the hand holds by itself: which, where the hand took it and where the hand is now, in the
/// room. Where the view is drawn under the hand is its host's.
struct LayoutItemHand: Equatable {
    let identity: Int
    let from: Point
    var at: Point
}
