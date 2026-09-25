// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI

/// A RadioButton: a WinUI `RadioButton` and its caption; which of its set loses its check is the host's.
@MainActor
final class WinUIRadioButtonView: WinUIToggleView, WinUIWordsView {
    init() {
        super.init { number in stateui_winui_radio_make(number) }
    }

    func setText(_ text: String) {
        stateui_winui_set_caption(handle, text)
    }

    /// The caption the button shows now, read back from WinUI.
    var text: String {
        WinUIView.words(of: handle)
    }
}
