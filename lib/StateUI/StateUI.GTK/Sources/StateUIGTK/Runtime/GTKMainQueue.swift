// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUIHost
import CStateUIGTK

/// libdispatch's main queue, drained on GLib's main loop as its handle signals: an application's
/// `DispatchQueue.main.async` runs on the UI thread.
/// Design: docs/design/platforms/gtk/runtime.md#the-main-queue
enum GTKMainQueue {
    @MainActor private static var watched = false

    /// Watches the queue's handle from the main loop, once.
    @MainActor static func watch() {
        guard !watched else { return }
        watched = true
        g_unix_fd_add(MainQueue.handle, STATEUI_IO_IN, { _, _, _ in
            MainActor.assumeIsolated { MainQueue.drain() }
            return 1
        }, nil)
    }
}
