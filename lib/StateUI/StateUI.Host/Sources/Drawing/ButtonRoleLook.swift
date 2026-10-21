// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// How a button's role draws where the tree draws nothing of its own, the same on every host: the main action filled
/// in the platform's accent, an action that destroys something with its words in the platform's color for one, the
/// way out and a button of no role as the platform's plain one. A fill or a color of words the tree states wins.
/// Design: docs/design/host/layout.md#a-buttons-role
@_spi(Host) public struct ButtonRoleLook: Equatable, Sendable {
    /// Whether the button fills in the platform's accent.
    public let fillsInAccent: Bool

    /// Whether its words stand in the platform's color for an action that destroys something.
    public let wordsInCritical: Bool

    /// The look of `role` on a button whose tree states a fill where `fills`, and a color of its words where
    /// `colorsWords`.
    public init(_ role: ButtonRole?, fills: Bool, colorsWords: Bool) {
        fillsInAccent = role == .primary && !fills
        wordsInCritical = role == .destructive && !colorsWords
    }
}
