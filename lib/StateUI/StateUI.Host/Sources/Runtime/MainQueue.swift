// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if !canImport(Darwin) && !os(WASI)
import CStateUIHost
import Dispatch
import StateUIFoundation
#if os(Windows)
import WinSDK
#endif

/// libdispatch's main queue where no run loop of the platform's turns it - Linux, Android, Windows: the handle a
/// host's loop watches, and the drain it runs on the UI thread as the handle signals. So an application's
/// `DispatchQueue.main.async` runs on the UI thread on these platforms as on Apple's.
/// Design: docs/design/host/runtime.md#the-main-queue
@_spi(Host) public enum MainQueue {
    /// What a host's loop watches: an eventfd, readable while the queue holds work - on Windows an event, set.
    public static var handle: StateUIMainQueueHandle {
        _dispatch_get_main_queue_handle_4CF()
    }

    /// The handle signaled: it is cleared, then what the queue holds runs - work queued meanwhile signals it again.
    /// Only on the UI thread: libdispatch binds its main queue to the thread it started on, the UI thread.
    @MainActor public static func drain() {
        #if os(Windows)
        ResetEvent(handle)
        #else
        var count: UInt64 = 0
        _ = read(handle, &count, MemoryLayout<UInt64>.size)
        #endif
        _dispatch_main_queue_callback_4CF(nil)
    }
}
#endif
