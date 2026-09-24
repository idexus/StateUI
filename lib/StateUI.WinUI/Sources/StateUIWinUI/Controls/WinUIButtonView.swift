// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI

/// A WinUI `Button`: its caption, whether it takes a press, and the click it raises.
@MainActor
final class WinUIButtonView: WinUIView {
    /// What the button does when the user clicks it.
    var onClicked: (() -> Void)?

    init() {
        super.init { number in stateui_winui_button_make(number) }
    }

    /// The caption.
    func setText(_ text: String) {
        stateui_winui_button_set_text(handle, text)
    }

    /// The caption the button shows now, read back from WinUI.
    var text: String {
        WinUIView.words(of: handle)
    }

    func setEnabled(_ enabled: Bool) {
        stateui_winui_set_enabled(handle, enabled)
    }

    override func clicked() {
        onClicked?()
    }

    override func detach() {
        onClicked = nil
    }
}
