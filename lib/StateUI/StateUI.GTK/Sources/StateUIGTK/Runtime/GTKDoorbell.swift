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

extension GTKDoorbell {
    /// Runs `work` once GTK has laid the frame out: at the priority after its layout and paint, then a turn.
    @MainActor static func afterLayout(_ work: @escaping @MainActor () -> Void) {
        pending.append(work)
        guard pending.count == 1 else { return }
        g_idle_add_full(G_PRIORITY_DEFAULT_IDLE, { _ in
            MainActor.assumeIsolated {
                let works = GTKDoorbell.pending
                GTKDoorbell.pending = []
                for work in works { work() }
                GTKRenderer.shared?.runtime.pump.turn()
            }
            return 0
        }, nil, nil)
    }

    /// Work waiting for the frame's layout.
    @MainActor private static var pending: [@MainActor () -> Void] = []
}
