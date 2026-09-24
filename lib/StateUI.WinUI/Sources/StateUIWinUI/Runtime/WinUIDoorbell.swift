// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIWinUI
import WinSDK

/// The doorbell: a thread parked until the core has work, posting a turn to the UI thread's queue.
/// Design: docs/design/platforms/winui/runtime.md#the-doorbell
enum WinUIDoorbell {
    /// Whether the thread runs.
    @MainActor private static var installed = false

    /// Starts the thread, once; each turn it posts reaches the host through the relay's `turn`.
    @MainActor static func install() {
        guard !installed else { return }
        installed = true
        startThread()
    }

    /// Started from a nonisolated function: a closure written in a `@MainActor` one is MainActor's.
    /// Design: docs/design/platforms/winui/runtime.md#the-doorbell
    private nonisolated static func startThread() {
        let thread = CreateThread(nil, 0, { _ in
            let core = CoreLink()
            while true {
                _ = core.waitForWork()
                stateui_winui_post_turn()
            }
        }, nil, 0, nil)
        if let thread { CloseHandle(thread) }
    }
}
