// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import Android
import CStateUIAndroid

/// The doorbell: a thread parked until a job comes from another thread, ringing the main looper through an eventfd -
/// the way the UI thread rings it for work of its own.
/// Design: docs/design/platforms/android/runtime.md#the-doorbell
enum AndroidDoorbell {
    /// The eventfd the doorbell's thread writes and the main looper watches.
    nonisolated(unsafe) private static var bell: Int32 = -1

    /// Gives the core the way to post a turn, and - once - watches the bell from the main looper, running a turn on
    /// each ring, and starts the thread.
    @MainActor static func install() {
        CoreLink().postTurns(with: { AndroidDoorbell.postTurn() })
        guard bell < 0 else { return }

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

        startThread()
    }

    /// Rings the bell the main looper watches, from any thread.
    nonisolated static func postTurn() {
        var one: UInt64 = 1
        _ = write(bell, &one, 8)
    }

    /// Started from a nonisolated function: a closure written in a `@MainActor` one would be MainActor's.
    /// Design: docs/design/platforms/android/runtime.md#the-doorbell
    private nonisolated static func startThread() {
        var thread: pthread_t = 0
        pthread_create(&thread, nil, { _ in CoreLink().ringForever() }, nil)
    }
}
