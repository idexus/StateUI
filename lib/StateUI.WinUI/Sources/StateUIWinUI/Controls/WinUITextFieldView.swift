// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIWinUI

/// A TextField: a WinUI `TextBox` on one line, whose typing reaches Swift through the relay as it happens.
/// Design: docs/design/platforms/winui/controls.md#a-field-and-its-words
@MainActor
final class WinUITextFieldView: WinUIView {
    /// What the field does when the user changes its words, handed all of them.
    var onTextChanged: ((String) -> Void)?

    /// What the field does when the user presses Enter in it.
    var onSubmitted: (() -> Void)?

    /// The most characters the user can type; nil for no bound.
    var maximumLength: Int?

    init() {
        super.init { number in stateui_winui_field_make(number) }
    }

    /// The words the field shows now, read back from WinUI.
    var text: String {
        WinUIView.words(of: handle)
    }

    /// Writes the words where they differ from the field's, with the caret after them.
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

    /// The words changed: kept within `maximumLength`, then handed on - a program's own write says nothing.
    func typed(_ text: String) {
        guard !ProgramWrite.isWriting else { return }

        var kept = text
        if let maximumLength, text.count > maximumLength {
            kept = String(text.prefix(maximumLength))
            ProgramWrite.perform { setText(kept) }
        }
        onTextChanged?(kept)
    }

    override func detach() {
        super.detach()
        onTextChanged = nil
        onSubmitted = nil
    }
}
