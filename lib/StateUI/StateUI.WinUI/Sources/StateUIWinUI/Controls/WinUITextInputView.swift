// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIWinUI

/// Words the user types - a WinUI `TextBox` on one line or several, or an `AutoSuggestBox` - whose typing reaches
/// Swift through the relay as it happens.
/// Design: docs/design/platforms/winui/controls.md#a-field-and-its-words
@MainActor
class WinUITextInputView: WinUIView {
    override var takesDirection: Bool { true }

    override var keepsTyping: Bool { true }

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

    /// The outline the tree gives the field - its color and width - and the shape its corners take, over the theme's
    /// frame in every state of the field's; the theme's where it gives none.
    /// Design: docs/design/platforms/winui/controls.md#a-fields-outline
    func setOutline(stroke: HostValue?, lineWidth: Double?, shape: HostValue?) {
        let outlined = shape.map(BoxArithmetic.outline)
        let outline = WinUIBrush(stroke)
        let width = BoxArithmetic.outlineWidth(stroke: stroke, width: lineWidth)
        let rounds = outlined.map { $0 != .rectangle } ?? false
        paint(.look, followsSize: outline.followsSize || rounds) { [handle] size in
            let radius = outlined.map { BoxArithmetic.cornerRadius(of: $0, width: size.width, height: size.height) } ?? -1
            outline.withRelayBrush(over: size) { brush in stateui_winui_field_set_outline(handle, brush, width, radius) }
        }
    }

    /// Writes the words where they differ from the view's, with the caret after them.
    func setText(_ text: String) {
        stateui_winui_field_set_text(handle, text)
    }

    /// The words shown while there are none.
    func setPlaceholder(_ placeholder: String?) {
        self.placeholder = placeholder
        stateui_winui_field_set_placeholder(handle, placeholder ?? "")
    }

    /// The words shown while there are none - which a field nothing sizes is at least as wide as.
    private var placeholder: String?

    /// A one-line field as WinUI measures it, at least twenty digits and its placeholder wide in its font, with its
    /// padding and border (`FieldWidth`); no wider than offered.
    /// Design: docs/design/host/layout.md#a-fields-own-width
    func measuredOnOneLine(width: Double?, height: Double?) -> LayoutSize {
        let own = super.measure(width: nil, height: height)
        let measured = FieldWidth.leastWords(placeholder: placeholder).map {
            stateui_winui_field_words_width(handle, $0).rounded(.up)
        }
        let wide = FieldWidth.width(own: own.width, measured: measured, chrome: stateui_winui_field_chrome(handle))
        return LayoutSize(width: width.map { min(wide, $0) } ?? wide, height: own.height)
    }

    /// How the words are taken: read only, and with `traits` - spell checked, predicted, and the keyboard's scope.
    func setBehavior(readOnly: Bool, traits: InputTraits) {
        stateui_winui_field_set_behavior(
            handle, readOnly, traits.checksSpelling, traits.predicts, WinUIInputScope(traits).rawValue)
    }

    /// The case the field holds its words in: WinUI puts each letter typed from the keyboard in it, and the host
    /// layer's rule the words that come any other way (`typed`).
    var textCase = TextCase.none

    /// The case typing takes.
    func setCasing(_ textCase: TextCase) {
        self.textCase = textCase
        stateui_winui_field_set_casing(handle, textCase.rawValue)
    }

    /// The words across the view, and the placeholder's color; nil for the platform's.
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

    /// The words changed: kept in the field's case within `maximumLength` - as typed while an input method is
    /// `composing` them (`InputWords.held`) - then handed on; a program's own write says nothing.
    func typed(_ text: String, composing: Bool) {
        guard !ProgramWrite.isWriting else { return }

        var kept = Self.lines(text)
        if let cut = InputWords.held(kept, in: textCase, toBound: maximumLength, composing: composing) {
            kept = cut
            ProgramWrite.perform { setText(cut) }
        }
        onTextChanged?(kept)
    }

    override func detach() {
        super.detach()
        onTextChanged = nil
        onSubmitted = nil
        // Gone from the tree, the field is typed into no more.
        stateui_winui_hear_focus(handle, number, false)
        if WinUIEditing.typed === self { WinUIEditing.typed = nil }
    }
}
