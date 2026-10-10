// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import Android
import CStateUIAndroid

/// The doorbell: the main looper rung through an eventfd from any thread - for a job queued, or work the UI thread
/// made.
/// Design: docs/design/platforms/android/runtime.md#the-doorbell
enum AndroidDoorbell {
    /// The eventfd a turn is rung on and the main looper watches.
    nonisolated(unsafe) private static var bell: Int32 = -1

    /// Watches the bell from the main looper, once, running a turn on each ring - then gives the core the way to
    /// post a turn.
    @MainActor static func install() {
        if bell < 0 { watch() }
        CoreLink().postTurns(with: { AndroidDoorbell.postTurn() })
    }

    @MainActor private static func watch() {
        bell = eventfd(0, Int32(EFD_CLOEXEC) | Int32(EFD_NONBLOCK))

        guard let looper = ALooper_forThread() else {
            AndroidRenderer.log.error("the doorbell found no looper on the main thread")
            return
        }

        ALooper_acquire(looper)
        ALooper_addFd(looper, bell, Int32(ALOOPER_POLL_CALLBACK), Int32(ALOOPER_EVENT_INPUT), { descriptor, _, _ in
            var count: UInt64 = 0
            _ = read(descriptor, &count, 8)
            MainActor.assumeIsolated { Java.frame { AndroidRenderer.shared?.runtime.pump.turn() } }
            return 1
        }, nil)
    }

    /// Rings the bell the main looper watches, from any thread.
    nonisolated static func postTurn() {
        var one: UInt64 = 1
        _ = write(bell, &one, 8)
    }
}
