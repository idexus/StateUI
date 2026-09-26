// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
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
        didSet { if held != oldValue, ticksWithWinUI { stateui_winui_hold_frames(held) } }
    }

    /// Whether WinUI's composed frames drive the clock; a clock a test winds gets its frames from the test.
    let ticksWithWinUI: Bool

    /// The one clock, which the relay's frame reaches.
    static var current: WinUIFrameClock?

    /// A clock on the performance counter, whose frames are WinUI's.
    convenience init() {
        self.init(now: WinUIFrameClock.monotonic, ticksWithWinUI: true)
    }

    /// A clock telling `now`'s time, its frames WinUI's where `ticksWithWinUI`, and otherwise whoever tells its time.
    /// A new clock holds nothing: the frames a clock before it held are let go.
    init(now: @escaping () -> Double, ticksWithWinUI: Bool) {
        self.now = now
        self.ticksWithWinUI = ticksWithWinUI
        Self.current = self
        stateui_winui_hold_frames(false)
    }

    /// A frame WinUI composes: the frame's work at this moment, on a clock WinUI's frames drive.
    func frame() {
        guard held, ticksWithWinUI else { return }
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
