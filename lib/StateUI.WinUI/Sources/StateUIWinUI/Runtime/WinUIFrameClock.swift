// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIWinUI
import WinSDK

/// The frame clock: the frames WinUI composes, through `CompositionTarget.Rendering`, subscribed while held.
/// Design: docs/design/platforms/winui/runtime.md#one-frame
@MainActor
final class WinUIFrameClock: FrameClock {
    /// The runtime's time, in milliseconds on the performance counter.
    let now: () -> Double

    /// What a frame does, handed that frame's time.
    var onFrame: ((Double) -> Void)?

    /// Whether something holds the clock. Frames come only while it does.
    var held = false {
        didSet { if held != oldValue { stateui_winui_hold_frames(held) } }
    }

    /// The one clock, which the relay's frame reaches.
    static var current: WinUIFrameClock?

    /// A clock telling `now`'s time: the performance counter's, or a test's hand-wound one.
    init(now: @escaping () -> Double = WinUIFrameClock.monotonic) {
        self.now = now
        Self.current = self
    }

    /// A frame WinUI composes: the frame's work at this moment.
    func frame() {
        guard held else { return }
        onFrame?(now())
    }

    /// Milliseconds on the performance counter.
    nonisolated static func monotonic() -> Double {
        var count = LARGE_INTEGER()
        var frequency = LARGE_INTEGER()
        QueryPerformanceCounter(&count)
        QueryPerformanceFrequency(&frequency)
        return Double(count.QuadPart) * 1_000 / Double(frequency.QuadPart)
    }
}
