// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIWinUI

/// The doorbell: a turn posted to the UI thread's queue from any thread - for a job queued, or work the UI thread
/// made.
/// Design: docs/design/platforms/winui/runtime.md#the-doorbell
enum WinUIDoorbell {
    /// Gives the core the way to post a turn; each turn posted reaches the host through the relay's `turn`.
    @MainActor static func install() {
        CoreLink().postTurns(with: { stateui_winui_post_turn() })
    }

    /// A turn the relay posted: the work a layout pass left, then the turn.
    @MainActor static func turn() {
        guard let runtime = WinUIRenderer.shared?.runtime else { return }
        runtime.afterLayout.passEnded()
        runtime.pump.turn()
    }
}
