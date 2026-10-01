// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI

/// A Switch: a WinUI `ToggleSwitch`.
@MainActor
final class WinUISwitchView: WinUIToggleView {
    init() {
        super.init { number in stateui_winui_switch_make(number) }
    }
}
