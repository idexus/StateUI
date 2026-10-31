// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIGTK

/// Words the user types - a field on one line or an editor of several - whose changes reach Swift as they happen.
/// Design: docs/design/platforms/gtk/controls.md#a-field-and-its-words
@MainActor
protocol GTKTextInputView: GTKView {
    /// What the view does when the user changes its words, handed all of them.
    var onTextChanged: ((String) -> Void)? { get set }

    /// The class drawing the outline and the shape the tree gives the view; nil for the platform's.
    var outlineClass: String? { get set }

    /// The words the view shows now, read back from GTK.
    var text: String { get }

    /// Writes the words where they differ from the view's, with the caret after them.
    func setText(_ text: String)

    /// The words shown while there are none.
    func setPlaceholder(_ placeholder: String?)

    /// The most characters the user can type; nil for no bound.
    func setMaximumLength(_ length: Int?)

    /// The case the view holds its words in, the program's and those typed alike; nil as written.
    func setTextCase(_ textCase: TextCase?)

    /// Whether the user can change the words, and what the input method is told of them.
    func setBehavior(readOnly: Bool, hints: GtkInputHints, purpose: GtkInputPurpose)

    /// The words across the view.
    func setAlignment(_ alignment: TextAlignment)

    /// The class of the display-wide sheet giving the words their look.
    func setWordsClass(_ name: String?)

    /// Whether every digit stands as wide as the others, as the words' own attribute.
    func setTabularDigits(_ tabular: Bool)

    /// Puts the caret `start` characters in and selects `length` from it.
    func select(start: Int, length: Int)
}

extension GTKTextInputView {
    /// What GTK tells the input method of words typed with `traits`.
    /// Design: docs/design/platforms/gtk/controls.md#a-field-and-its-words
    static func input(_ traits: InputTraits) -> (GtkInputHints, GtkInputPurpose) {
        var hints = (traits.checksSpelling ? GTK_INPUT_HINT_SPELLCHECK : GTK_INPUT_HINT_NO_SPELLCHECK).rawValue
        if traits.predicts { hints |= GTK_INPUT_HINT_WORD_COMPLETION.rawValue }
        if traits.offersEmoji { hints |= GTK_INPUT_HINT_EMOJI.rawValue }
        if traits.capitals == .sentences { hints |= GTK_INPUT_HINT_UPPERCASE_SENTENCES.rawValue }
        let purpose = switch traits.keys {
        case .words: GTK_INPUT_PURPOSE_FREE_FORM
        case .email: GTK_INPUT_PURPOSE_EMAIL
        case .number: GTK_INPUT_PURPOSE_NUMBER
        case .digits: GTK_INPUT_PURPOSE_DIGITS
        case .telephone: GTK_INPUT_PURPOSE_PHONE
        case .url: GTK_INPUT_PURPOSE_URL
        }
        return (GtkInputHints(rawValue: hints), purpose)
    }
}

extension GTKTextInputView {
    /// The outline the tree gives the view - its color and width - and the shape its ground and outline follow, as a
    /// class of the host's style sheet over the theme's frame; the theme's where it gives none.
    /// Design: docs/design/platforms/gtk/controls.md#a-fields-outline
    func setOutline(stroke: HostValue?, lineWidth: Double?, shape: HostValue?) {
        let drawn = GTKStyleSheet.box(
            fill: nil, stroke: stroke.flatMap { GTKBrush($0).firstColor },
            lineWidth: stroke == nil ? nil : BoxArithmetic.outlineWidth(stroke: stroke, width: lineWidth),
            shape: shape.map(BoxArithmetic.outline))
        swapClass(&outlineClass, to: drawn)
    }
}
