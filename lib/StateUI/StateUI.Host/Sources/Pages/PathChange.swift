// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// How a navigation stack's pages change, and whether the change moves on screen, the same on every host.
/// Design: docs/design/host/pages.md#a-path-that-changes
@_spi(Host) public enum PathChange: Equatable, Sendable {
    /// Pages joining on top of every page that stays: the last of them arrives.
    case push

    /// The pages above the first `staying` taken away: one move back to the page on top of those that stay.
    case pop(staying: Int)

    /// Any other change - a page under the top replaced, the first pages a stack shows, the stack emptied - which
    /// does not move.
    case replace

    /// The change from the pages `old` to `new`, told apart by `same`; nil where they are the same pages.
    public static func of<Page>(from old: [Page], to new: [Page], same: (Page, Page) -> Bool) -> PathChange? {
        let kept = zip(old, new).prefix { same($0, $1) }.count
        if kept == old.count, kept == new.count { return nil }
        if kept == old.count, kept > 0 { return .push }
        if kept == new.count, kept > 0 { return .pop(staying: kept) }
        return .replace
    }

    /// Whether the change moves on screen: a push and a pop do, a replacement does not, and none does for a user
    /// who asked for less motion.
    public func moves(reducingMotion: Bool) -> Bool {
        guard !reducingMotion else { return false }
        if case .replace = self { return false }
        return true
    }
}
