// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIWinUI

/// A SearchField: WinUI's `AutoSuggestBox` with its search glyph, whose query submits. The box types in the text box
/// its template holds, which takes what the box says of it: whether it is read only, the case typing takes and the
/// words typed across it.
@MainActor
final class WinUISearchFieldView: WinUIInputView {
    private var readOnly = false
    private var textCase = TextCase.none
    private var alignment = TextAlignment.start

    init() {
        super.init { number in stateui_winui_search_make(number) }
    }

    override func setCasing(_ textCase: TextCase) {
        self.textCase = textCase
        styleTheBox()
    }

    /// Whether the user can change the words.
    func setReadOnly(_ readOnly: Bool) {
        self.readOnly = readOnly
        styleTheBox()
    }

    /// The words typed across the box; its placeholder stands at the start whatever it says.
    func setAlignment(_ alignment: TextAlignment) {
        self.alignment = alignment
        styleTheBox()
    }

    private func styleTheBox() {
        stateui_winui_search_set_box(handle, readOnly, textCase.rawValue, alignment.rawValue)
    }
}
