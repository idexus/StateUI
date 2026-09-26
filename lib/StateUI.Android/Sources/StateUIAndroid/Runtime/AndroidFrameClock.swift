// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import Android
import CStateUIAndroid

/// The frame clock: the display's frames through the UI thread's `Choreographer`, asked for one at a time while held.
/// Design: docs/design/platforms/android/runtime.md#one-frame
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

    /// The one clock, which the frame callback reaches.
    static var current: AndroidFrameClock?

    /// The UI thread's choreographer and the one callback it is handed, made once for the process.
    private static let choreographer = JavaObject(
        Java.callStaticObject(JavaAPI.choreographer, JavaAPI.choreographerInstance)!)
    private static let callback = Java.new(JavaAPI.frameCallback, JavaAPI.newFrameCallback)

    /// A clock telling `now`'s time: the monotonic clock's, or a test's hand-wound one.
    init(now: @escaping () -> Double = AndroidFrameClock.monotonic) {
        self.now = now
        Self.current = self
    }

    private func post() {
        guard !posted else { return }

        posted = true
        Java.call(Self.choreographer.reference, JavaAPI.postFrameCallback, .object(Self.callback.reference))
    }

    /// The display's frame at `time`: the frame's work, then the next frame while something holds the clock.
    func frame(_ time: Double) {
        posted = false
        guard held else { return }

        onFrame?(time)
        if held { post() }
    }

    /// Milliseconds on `CLOCK_MONOTONIC`, the clock the choreographer stamps frames with.
    nonisolated static func monotonic() -> Double {
        var time = timespec()
        clock_gettime(CLOCK_MONOTONIC, &time)
        return Double(time.tv_sec) * 1_000 + Double(time.tv_nsec) / 1_000_000
    }
}
