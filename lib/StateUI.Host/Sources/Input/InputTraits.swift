// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What the platform's keyboard and its checking of the words do for a view the user types into, by whether the
/// tree has them spell checked and predicted and what they are for - the same on every host.
/// Design: docs/design/host/runtime.md#what-typing-is-given
@_spi(Host) public struct InputTraits: Equatable, Sendable {
    /// The keys a keyboard on the screen offers.
    public enum Keys: Equatable, Sendable {
        case words, email, number, telephone, url
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

    /// Whether misspelt words are marked.
    public var checksSpelling: Bool

    /// Whether the platform corrects and replaces words as they are typed.
    public var corrects: Bool

    /// Whether the platform offers the words it expects next.
    public var predicts: Bool

    /// Whether the keyboard offers emoji to hand.
    public var offersEmoji = false

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
        case .email: (keys, capitals) = (.email, .none)
        case .numeric: keys = .number
        case .telephone: keys = .telephone
        case .url: (keys, capitals) = (.url, .none)
        }
    }

    /// The members the traits are read from.
    public static let members: [any ContractMember] = [
        InputViewContract.isSpellCheckEnabled, InputViewContract.isTextPredictionEnabled,
        InputViewContract.inputPurpose,
    ]

    /// The traits `values` give.
    public init<Realized>(_ values: ElementValues<Realized>) {
        self.init(
            spellChecked: values[InputViewContract.isSpellCheckEnabled] ?? true,
            predicted: values[InputViewContract.isTextPredictionEnabled] ?? true,
            purpose: values[InputViewContract.inputPurpose])
    }

    /// The traits `values` give where one of their members changed; nil where none did.
    public static func changed<Realized>(_ values: ElementValues<Realized>) -> InputTraits? {
        guard values.changed(InputViewContract.isSpellCheckEnabled)
            || values.changed(InputViewContract.isTextPredictionEnabled)
            || values.changed(InputViewContract.inputPurpose)
        else { return nil }
        return InputTraits(values)
    }
}
