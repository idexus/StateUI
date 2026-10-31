// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUIHost
import Android
import CStateUIAndroid

/// libdispatch's main queue, drained on the main looper as its handle signals: an application's
/// `DispatchQueue.main.async` runs on the UI thread.
/// Design: docs/design/platforms/android/runtime.md#the-main-queue
enum AndroidMainQueue {
    @MainActor private static var watched = false

    /// Watches the queue's handle from the main looper, once.
    @MainActor static func watch() {
        guard !watched else { return }
        guard let looper = ALooper_forThread() else {
            AndroidRenderer.log.error("the main queue found no looper on the main thread")
            return
        }
        watched = true
        ALooper_acquire(looper)
        ALooper_addFd(looper, MainQueue.handle, Int32(ALOOPER_POLL_CALLBACK), Int32(ALOOPER_EVENT_INPUT), { _, _, _ in
            MainActor.assumeIsolated { Java.frame { MainQueue.drain() } }
            return 1
        }, nil)
    }
}
