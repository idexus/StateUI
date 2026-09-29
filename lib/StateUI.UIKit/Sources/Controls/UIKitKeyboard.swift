// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What the keyboard is told of the words a view takes: whether they are spell checked and predicted, and what they
/// are for.
@MainActor
struct UIKitKeyboard {
    var keyboardType = UIKeyboardType.default
    var capitalization = UITextAutocapitalizationType.sentences
    var content: UITextContentType?
    var spellChecking = UITextSpellCheckingType.default
    var correction = UITextAutocorrectionType.default
    var prediction = UITextInlinePredictionType.default

    init(spellChecked: Bool, predicted: Bool, purpose: InputPurpose?) {
        spellChecking = spellChecked ? .yes : .no
        correction = predicted ? .yes : .no
        prediction = predicted ? .yes : .no
        switch purpose ?? .default {
        case .default: break
        case .text: capitalization = .sentences
        case .plain:
            (spellChecking, correction, prediction, capitalization) = (.no, .no, .no, .none)
        case .chat: keyboardType = .default
        case .email: (keyboardType, content, capitalization) = (.emailAddress, .emailAddress, .none)
        case .numeric: keyboardType = .decimalPad
        case .telephone: (keyboardType, content) = (.phonePad, .telephoneNumber)
        case .url: (keyboardType, content, capitalization) = (.URL, .URL, .none)
        }
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
