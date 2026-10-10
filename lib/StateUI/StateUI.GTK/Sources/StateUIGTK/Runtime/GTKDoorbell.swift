// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIGTK

/// The doorbell: a turn posted to GLib's main loop from any thread - for a job queued, or work the UI thread made.
/// Design: docs/design/platforms/gtk/runtime.md#the-doorbell
enum GTKDoorbell {
    /// Gives the core the way to post a turn.
    @MainActor static func install() {
        CoreLink().postTurns(with: { GTKDoorbell.postTurn() })
    }

    /// Posts one turn to the main loop, at input's priority, so it lands before the next paint.
    nonisolated static func postTurn() {
        g_idle_add_full(G_PRIORITY_DEFAULT, { _ in
            MainActor.assumeIsolated { GTKRenderer.shared?.runtime.pump.turn() }
            return 0
        }, nil, nil)
    }
}
