// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import WinSDK
@_spi(Host) import StateUIHost
import CStateUIWinUI

/// libdispatch's main queue, drained on the UI thread: the thread pool waits on its handle and posts a turn.
/// Design: docs/design/platforms/winui/runtime.md#the-main-queue
enum WinUIMainQueue {
    @MainActor private static var wait: PTP_WAIT?

    private static let signaled: PTP_WAIT_CALLBACK = { _, _, _, _ in stateui_winui_post_turn() }

    /// Waits on the queue's handle, once.
    @MainActor static func watch() {
        guard wait == nil else { return }
        wait = CreateThreadpoolWait(signaled, nil, nil)
        drain()
    }

    /// Runs what the queue holds - nothing where it holds nothing - and waits again: a wait ends at its signal.
    @MainActor static func drain() {
        guard let wait else { return }
        MainQueue.drain()
        SetThreadpoolWait(wait, MainQueue.handle, nil)
    }
}
