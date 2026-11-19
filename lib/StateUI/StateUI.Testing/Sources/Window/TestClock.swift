// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A clock a test winds by hand. The window it is given stands at the clock's time: a movement begun in it travels
/// only as the test advances the clock, so a test stops half-way, reads, interrupts and goes on, with no waiting.
///
///     let clock = TestClock()
///     let window = try await TestWindow(clock: clock) { PanelPage() }
///
///     try window.element("panel.open").send(.activate)
///     try await clock.advance(by: .milliseconds(150))
///     // Half-way through a movement of 300 milliseconds.
///
/// One clock winds one window at a time.
@MainActor
public final class TestClock {
    /// The time the window's frames run at, which the driver reads.
    /// Design: docs/design/host/testing.md#a-clock-wound-by-hand
    let source = StateUIHost.TestClock()

    /// The window this clock winds; a closed one is wound no more.
    weak var window: TestWindow?

    /// A clock at nought, winding no window yet.
    public init() {}

    /// How far the clock has been advanced.
    public var now: Duration { .milliseconds(source.now) }

    /// Advances the clock by `duration`, a display frame at every `step` and a last, shorter one for what is left:
    /// each frame moves what is under way to its time and runs the work that came ready.
    ///
    ///     try await clock.advance(by: .milliseconds(250))
    ///
    /// - Parameters:
    ///   - duration: how far to advance; nought advances nothing.
    ///   - step: the time between two frames.
    /// - Throws: `TestFailure` where `duration` is negative or `step` is not positive, and where the clock winds no
    ///   open window.
    public func advance(by duration: Duration, step: Duration = .milliseconds(10)) async throws {
        guard duration >= .zero else {
            throw TestFailure(description: "a clock is never wound back: it was advanced by \(duration)")
        }
        guard step > .zero else {
            throw TestFailure(description: "a clock advances by steps longer than nothing: its step was \(step)")
        }
        guard let window, window.isOpen else {
            throw TestFailure(description: "the clock winds no open window: nothing stands at its time")
        }

        var left = duration
        while left > .zero {
            let taken = min(step, left)
            left -= taken
            source.now += Self.milliseconds(taken)
            try await window.frame()
        }
    }

    /// A length of time as the frames count it.
    private static func milliseconds(_ length: Duration) -> Double {
        Double(length.components.seconds) * 1_000 + Double(length.components.attoseconds) / 1e15
    }
}
