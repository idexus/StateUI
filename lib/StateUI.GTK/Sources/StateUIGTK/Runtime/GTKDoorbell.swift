// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIGTK

/// The doorbell: a thread parked until the core has work, posting a turn to GLib's main loop.
/// Design: docs/design/platforms/gtk/runtime.md#the-doorbell
enum GTKDoorbell {
    /// Whether the thread runs.
    @MainActor private static var installed = false

    /// Starts the thread, once.
    @MainActor static func install() {
        guard !installed else { return }
        installed = true
        startThread()
    }

    /// Started from a nonisolated function: a closure written in a `@MainActor` one is MainActor's.
    private nonisolated static func startThread() {
        _ = g_thread_new("stateui-doorbell", { _ in
            let core = CoreLink()
            while true {
                _ = core.waitForWork()
                GTKDoorbell.postTurn()
            }
        }, nil)
    }

    /// Posts one turn to the main loop, at input's priority, so it lands before the next paint.
    nonisolated static func postTurn() {
        g_idle_add_full(G_PRIORITY_DEFAULT, { _ in
            MainActor.assumeIsolated { GTKRenderer.shared?.pump.turn() }
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
                GTKRenderer.shared?.pump.turn()
            }
            return 0
        }, nil, nil)
    }

    /// Work waiting for the frame's layout.
    @MainActor private static var pending: [@MainActor () -> Void] = []
}
