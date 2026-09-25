// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIWinUI

/// Words the user types - a WinUI `TextBox` on one line or several, or an `AutoSuggestBox` - whose typing reaches
/// Swift through the relay as it happens.
/// Design: docs/design/platforms/winui/controls.md#a-field-and-its-words
@MainActor
class WinUIInputView: WinUIView {
    /// What the view does when the user changes its words, handed all of them.
    var onTextChanged: ((String) -> Void)?

    /// What the view does when the user submits it: Enter in a field, a search box's query.
    var onSubmitted: (() -> Void)?

    /// The most characters the user can type; nil for no bound.
    var maximumLength: Int?

    /// The words the view shows now, read back from WinUI.
    var text: String {
        Self.lines(WinUIView.words(of: handle))
    }

    /// `words` with each line ending as StateUI's does: WinUI's text box ends a line with a carriage return.
    /// Design: docs/design/platforms/winui/controls.md#a-field-and-its-words
    private static func lines(_ words: String) -> String {
        words.replacing("\r\n", with: "\n").replacing("\r", with: "\n")
    }

    /// Writes the words where they differ from the view's, with the caret after them.
    func setText(_ text: String) {
        stateui_winui_field_set_text(handle, text)
    }

    /// The words shown while there are none.
    func setPlaceholder(_ placeholder: String?) {
        stateui_winui_field_set_placeholder(handle, placeholder ?? "")
    }

    func setEnabled(_ enabled: Bool) {
        stateui_winui_set_enabled(handle, enabled)
    }

    /// How the words are taken: read only, spell checked, predicting the next word, and what they are for.
    func setBehaviour(readOnly: Bool, spellChecked: Bool, predicted: Bool, purpose: InputPurpose?) {
        stateui_winui_field_set_behaviour(handle, readOnly, spellChecked, predicted, purpose?.rawValue ?? 0)
    }

    /// The words across the view, and the placeholder's colour; nil for the platform's.
    func setLook(alignment: TextAlignment, placeholderColor: HostValue?) {
        let argb = placeholderColor?.argb
        stateui_winui_field_set_look(handle, alignment.rawValue, argb ?? 0, argb != nil)
    }

    /// Puts the caret `start` characters in and selects `length` from it, in the UTF-16 units WinUI counts
    /// (`InputWords.utf16Selection`).
    func select(start: Int, length: Int) {
        let units = InputWords.utf16Selection(start: start, length: length, in: text)
        stateui_winui_field_select(handle, Int32(clamping: units.start), Int32(clamping: units.length))
    }

    /// The words changed: kept within `maximumLength`, then handed on - a program's own write says nothing.
    func typed(_ text: String) {
        guard !ProgramWrite.isWriting else { return }

        var kept = Self.lines(text)
        if let cut = InputWords.cut(kept, toBound: maximumLength) {
            kept = cut
            ProgramWrite.perform { setText(cut) }
        }
        onTextChanged?(kept)
    }

    override func detach() {
        super.detach()
        onTextChanged = nil
        onSubmitted = nil
    }
}
