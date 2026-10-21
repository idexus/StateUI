// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A closed vocabulary, numbered by StateUI: append a case, never insert one.
// Design: docs/design/types/vocabularies.md#written-out-and-appended

/// What a text input is for, which picks the on-screen keyboard the platform
/// offers and what it fills the input in with.
public enum InputPurpose: Int32, Sendable {
    /// Whatever the platform offers, with its own correction and capitalization.
    case `default` = 0

    /// The default one with no correction, capitalization or suggestions.
    case plain = 1

    /// Set up for conversation - emoji, and no autocorrection getting in the way.
    case chat = 2

    /// With @ and . to hand.
    case email = 3

    /// Digits only.
    case numeric = 4

    /// A phone dialler's keypad.
    case telephone = 5

    /// General text, with the platform's spellcheck and capitalization.
    case text = 6

    /// With / and .com to hand.
    case url = 7

    /// The name a user signs in with: no correction or capitals, and the names the platform keeps offered.
    case username = 8

    /// A password being made, on a field `isPassword` hides: the platform offers a strong one and keeps it.
    case newPassword = 9

    /// A code sent to sign in with: digits, and the code the platform received offered.
    case oneTimeCode = 10
}

extension InputPurpose: HostRepresentable {}
extension InputPurpose: StateChoice {}
