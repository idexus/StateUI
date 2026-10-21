// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What the platform's keyboard and its checking of the words do for a view the user types into, by whether the
/// tree has them spell checked and predicted and what they are for - the same on every host.
/// Design: docs/design/host/runtime.md#what-typing-is-given
@_spi(Host) public struct InputTraits: Equatable, Sendable {
    /// The keys a keyboard on the screen offers.
    public enum Keys: Equatable, Sendable {
        /// Letters, for prose.
        case words
        /// Letters with the at sign, for an address.
        case email
        /// Digits, with the decimal point.
        case number
        /// Digits alone, for a code.
        case digits
        /// A telephone's keys.
        case telephone
        /// Letters with the slash and the dot, for a web address.
        case url
    }

    /// What the words are, so the platform fills them in with what it keeps for them.
    public enum Content: Equatable, Sendable {
        /// An e-mail address.
        case emailAddress
        /// A telephone number.
        case telephoneNumber
        /// A web address.
        case url
        /// The name a user signs in with - a saved one offered.
        case username
        /// A password being made - a strong one offered, and kept.
        case newPassword
        /// A code sent to sign in with - the one received offered.
        case oneTimeCode
    }

    /// Where the platform puts letters in capitals as the user types.
    public enum Capitals: Equatable, Sendable {
        /// Wherever the platform does of its own accord.
        case platform

        /// The first letter of each sentence.
        case sentences

        /// None: the words stay as they are typed.
        case none
    }

    /// The keys a keyboard on the screen offers.
    public var keys = Keys.words

    /// Where the platform puts letters in capitals as the user types.
    public var capitals = Capitals.platform

    /// Whether misspelled words are marked.
    public var checksSpelling: Bool

    /// Whether the platform corrects and replaces words as they are typed.
    public var corrects: Bool

    /// Whether the platform offers the words it expects next.
    public var predicts: Bool

    /// Whether the keyboard offers emoji to hand.
    public var offersEmoji = false

    /// What the words are, which the platform fills them in from; nil where it keeps nothing for them.
    public var content: Content?

    /// The traits of words spell checked and predicted as the tree says, for `purpose`; nil for the default one.
    public init(spellChecked: Bool, predicted: Bool, purpose: InputPurpose?) {
        checksSpelling = spellChecked
        corrects = predicted
        predicts = predicted
        switch purpose ?? .default {
        case .default: break
        case .text: capitals = .sentences
        case .plain: (checksSpelling, corrects, predicts, capitals) = (false, false, false, .none)
        case .chat: offersEmoji = true
        case .email: (keys, capitals, content) = (.email, .none, .emailAddress)
        case .numeric: keys = .number
        case .telephone: (keys, content) = (.telephone, .telephoneNumber)
        case .url: (keys, capitals, content) = (.url, .none, .url)
        case .username:
            (checksSpelling, corrects, predicts, capitals, content) = (false, false, false, .none, .username)
        case .newPassword:
            (checksSpelling, corrects, predicts, capitals, content) = (false, false, false, .none, .newPassword)
        case .oneTimeCode:
            (keys, checksSpelling, corrects, predicts, content) = (.digits, false, false, false, .oneTimeCode)
        }
    }

    /// The members the traits are read from.
    public static let members: [any ContractMember] = [
        TextInputContract.isSpellCheckEnabled, TextInputContract.isTextPredictionEnabled,
        TextInputContract.inputPurpose,
    ]

    /// The traits `values` give.
    public init<Realized>(_ values: ElementValues<Realized>) {
        self.init(
            spellChecked: values[TextInputContract.isSpellCheckEnabled] ?? true,
            predicted: values[TextInputContract.isTextPredictionEnabled] ?? true,
            purpose: values[TextInputContract.inputPurpose])
    }

    /// The traits `values` give where one of their members changed; nil where none did.
    public static func changed<Realized>(_ values: ElementValues<Realized>) -> InputTraits? {
        guard values.changed(TextInputContract.isSpellCheckEnabled)
            || values.changed(TextInputContract.isTextPredictionEnabled)
            || values.changed(TextInputContract.inputPurpose)
        else { return nil }
        return InputTraits(values)
    }

    /// The return key a field asks the keyboard for: the one the tree wrote, else a search's for a search field and
    /// the platform's own for any other.
    public static func submitLabel(_ written: SubmitLabel?, searching: Bool) -> SubmitLabel {
        written ?? (searching ? .search : .default)
    }
}
