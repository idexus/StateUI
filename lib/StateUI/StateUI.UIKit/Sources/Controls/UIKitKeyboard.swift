// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What the keyboard is told of the words a view takes, by their traits (`InputTraits`): whether they are spell
/// checked and predicted, what they are for, and what they are, which iOS fills them in from.
@MainActor
struct UIKitKeyboard {
    var keyboardType = UIKeyboardType.default
    var capitalization = UITextAutocapitalizationType.sentences
    var content: UITextContentType?
    var spellChecking = UITextSpellCheckingType.default
    var correction = UITextAutocorrectionType.default
    var prediction = UITextInlinePredictionType.default

    init(_ traits: InputTraits) {
        keyboardType = switch traits.keys {
        case .words: .default
        case .email: .emailAddress
        case .number: .decimalPad
        case .digits: .numberPad
        case .telephone: .phonePad
        case .url: .URL
        }
        content = switch traits.content {
        case .emailAddress: .emailAddress
        case .telephoneNumber: .telephoneNumber
        case .url: .URL
        case .username: .username
        case .newPassword: .newPassword
        case .oneTimeCode: .oneTimeCode
        case nil: nil
        }
        capitalization = traits.capitals == .none ? .none : .sentences
        spellChecking = traits.checksSpelling ? .yes : .no
        correction = traits.corrects ? .yes : .no
        prediction = traits.predicts ? .yes : .no
    }

    func apply(to field: UITextField) {
        field.keyboardType = keyboardType
        field.autocapitalizationType = capitalization
        field.textContentType = content
        field.spellCheckingType = spellChecking
        field.autocorrectionType = correction
        field.inlinePredictionType = prediction
    }

    func apply(to editor: UITextView) {
        editor.keyboardType = keyboardType
        editor.autocapitalizationType = capitalization
        editor.textContentType = content
        editor.spellCheckingType = spellChecking
        editor.autocorrectionType = correction
        editor.inlinePredictionType = prediction
    }
}
#endif
