// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The item the program scrolled a list to, and where it stands: the start, the center, the end or nearest.
/// Design: docs/design/host/items.md#scrolling-to-an-item
@_spi(Host) public struct ItemsScrollTarget: Equatable, Sendable {
    /// The item's identity.
    public let identity: String

    /// Where in the list's room it stands.
    public let anchor: ScrollAnchor

    /// The item of `identity`, standing where `anchor` says.
    public init(identity: String, anchor: ScrollAnchor) {
        self.identity = identity
        self.anchor = anchor
    }

    /// Whether a scroll to an item glides there, the same on every host: unless the user asked for less motion.
    /// Design: docs/design/host/items.md#scrolling-to-an-item
    public static func glides(reducingMotion: Bool) -> Bool {
        !reducingMotion
    }
}
