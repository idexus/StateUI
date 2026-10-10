// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
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
    var isAnimating: Bool { stateui_winui_progress_ring_running(handle) }

    /// None: WinUI paints a progress ring's Background as its track, which a colour there would recolour - its
    /// register's `notPlanned`.
    override func setBackground(_ value: HostValue?) {}
}
