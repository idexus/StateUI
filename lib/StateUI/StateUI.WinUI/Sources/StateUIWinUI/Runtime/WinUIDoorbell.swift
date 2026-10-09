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
        let works = pending
        pending = []
        for work in works { work() }
        WinUIRenderer.shared?.runtime.pump.turn()
    }
}

extension WinUIDoorbell {
    /// Runs `work` in the next turn posted, once the layout pass under way is over: what a pass decides - a split
    /// view's first room - is said once WinUI has finished laying out.
    @MainActor static func afterPass(_ work: @escaping @MainActor () -> Void) {
        pending.append(work)
        stateui_winui_post_turn()
    }

    /// Work waiting for the pass under way to end.
    @MainActor private static var pending: [@MainActor () -> Void] = []
}
