// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIGTK

/// Words the user types - a field on one line or an editor of several - whose changes reach Swift as they happen.
/// Design: docs/design/platforms/gtk/controls.md#a-field-and-its-words
@MainActor
protocol GTKInputView: GTKView {
    /// What the view does when the user changes its words, handed all of them.
    var onTextChanged: ((String) -> Void)? { get set }

    /// The words the view shows now, read back from GTK.
    var text: String { get }

    /// Writes the words where they differ from the view's, with the caret after them.
    func setText(_ text: String)

    /// The words shown while there are none.
    func setPlaceholder(_ placeholder: String?)

    /// The most characters the user can type; nil for no bound.
    func setMaximumLength(_ length: Int?)

    /// Whether the user can change the words, and what the input method is told of them.
    func setBehaviour(readOnly: Bool, hints: GtkInputHints, purpose: GtkInputPurpose)

    /// The words across the view.
    func setAlignment(_ alignment: TextAlignment)

    /// The class of the display-wide sheet giving the words their look.
    func setWordsClass(_ name: String?)

    /// Puts the caret `start` characters in and selects `length` from it.
    func select(start: Int, length: Int)
}

extension GTKInputView {
    /// What GTK tells the input method of words the tree says are spell checked and predicted, and for `purpose`.
    static func input(spellChecked: Bool, predicted: Bool, purpose: InputPurpose?) -> (GtkInputHints, GtkInputPurpose) {
        var hints = (spellChecked ? GTK_INPUT_HINT_SPELLCHECK : GTK_INPUT_HINT_NO_SPELLCHECK).rawValue
        if predicted { hints |= GTK_INPUT_HINT_WORD_COMPLETION.rawValue }
        let kind: GtkInputPurpose
        switch purpose ?? .default {
        case .default, .text: kind = GTK_INPUT_PURPOSE_FREE_FORM
        case .plain:
            kind = GTK_INPUT_PURPOSE_FREE_FORM
            hints = GTK_INPUT_HINT_NO_SPELLCHECK.rawValue
        case .chat:
            kind = GTK_INPUT_PURPOSE_FREE_FORM
            hints |= GTK_INPUT_HINT_EMOJI.rawValue
        case .email: kind = GTK_INPUT_PURPOSE_EMAIL
        case .numeric: kind = GTK_INPUT_PURPOSE_NUMBER
        case .telephone: kind = GTK_INPUT_PURPOSE_PHONE
        case .url: kind = GTK_INPUT_PURPOSE_URL
        }
        if purpose == .text { hints |= GTK_INPUT_HINT_UPPERCASE_SENTENCES.rawValue }
        return (GtkInputHints(rawValue: hints), kind)
    }
}
