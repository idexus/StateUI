// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI

/// A CheckBox: a WinUI `CheckBox` with no caption, the box alone.
@MainActor
final class WinUICheckBoxView: WinUIToggleView {
    init() {
        super.init { number in stateui_winui_check_box_make(number) }
    }
}
