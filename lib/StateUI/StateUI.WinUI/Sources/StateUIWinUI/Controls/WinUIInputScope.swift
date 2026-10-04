// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUIHost

/// The input scope a text box is given, as the relay numbers WinUI's: the keys a keyboard on the screen offers, and
/// whether it starts sentences in capitals or offers emoji.
/// Design: docs/design/platforms/winui/controls.md#a-field-and-its-words
enum WinUIInputScope: Int32 {
    case `default`, text, chat, email, number, telephone, url

    /// The scope giving the keys `traits` ask for, a sentence's capitals and emoji among them.
    init(_ traits: InputTraits) {
        switch traits.keys {
        case .email: self = .email
        case .number: self = .number
        case .telephone: self = .telephone
        case .url: self = .url
        case .words: self = traits.offersEmoji ? .chat : traits.capitals == .sentences ? .text : .default
        }
    }
}
