// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import Android
import CStateUIAndroid

/// The frame clock: the display's frames through `AChoreographer`, asked for one at a time while held.
/// Design: docs/design/host/runtime.md#one-frame
@MainActor
final class AndroidFrameClock: FrameClock {
    /// The runtime's time, in milliseconds on the monotonic clock the display's frames are stamped on.
    let now: () -> Double

    /// What a frame of the display does, handed that frame's time.
    var onFrame: ((Double) -> Void)?

    /// Whether something holds the clock. Frames come only while it does.
    var held = false {
        didSet { if held { post() } }
    }

    /// Whether a frame is asked for and has not come.
    private var posted = false

    /// The one clock, which the choreographer's callback reaches.
    static var current: AndroidFrameClock?

    /// A clock telling `now`'s time: the monotonic clock's, or a test's hand-wound one.
    init(now: @escaping () -> Double = AndroidFrameClock.monotonic) {
        self.now = now
        Self.current = self
    }

    private func post() {
        guard !posted, let choreographer = AChoreographer_getInstance() else { return }

        posted = true
        AChoreographer_postFrameCallback(choreographer, { frameTime, _ in
            MainActor.assumeIsolated {
                Java.frame { AndroidFrameClock.current?.frame(Double(frameTime) / 1_000_000) }
            }
        }, nil)
    }

    private func frame(_ time: Double) {
        posted = false
        guard held else { return }

        onFrame?(time)
        if held { post() }
    }

    /// Milliseconds on `CLOCK_MONOTONIC`, the clock `AChoreographer` stamps frames with.
    nonisolated static func monotonic() -> Double {
        var time = timespec()
        clock_gettime(CLOCK_MONOTONIC, &time)
        return Double(time.tv_sec) * 1_000 + Double(time.tv_nsec) / 1_000_000
    }
}
