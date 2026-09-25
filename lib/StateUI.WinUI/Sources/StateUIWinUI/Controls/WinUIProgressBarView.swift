// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIWinUI

/// A ProgressBar: WinUI's `ProgressBar`, how far along from 0 to 1.
@MainActor
final class WinUIProgressBarView: WinUIView {
    init() {
        super.init { _ in stateui_winui_progress_bar_make() }
    }

    /// How far along, from 0 to 1: a share past either end standing at that end.
    func setProgress(_ progress: Double) {
        stateui_winui_progress_bar_set(handle, ValueArithmetic.share(progress))
    }

    /// How far along WinUI shows it.
    var progress: Double { stateui_winui_progress_bar_value(handle) }
}
