// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI

/// An ActivityIndicator: WinUI's `ProgressRing`, turning while its work runs.
@MainActor
final class WinUIActivityIndicatorView: WinUIView {
    init() {
        super.init { _ in stateui_winui_progress_ring_make() }
    }

    /// Whether it turns.
    func setRunning(_ running: Bool) {
        stateui_winui_progress_ring_set_running(handle, running)
    }

    /// Whether WinUI turns it.
    var isRunning: Bool { stateui_winui_progress_ring_running(handle) }
}
