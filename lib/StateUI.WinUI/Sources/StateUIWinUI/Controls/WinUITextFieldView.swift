// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI

/// A TextField: a WinUI `TextBox` on one line, whose Enter submits.
@MainActor
final class WinUITextFieldView: WinUIInputView {
    init() {
        super.init { number in stateui_winui_field_make(number) }
    }
}
