// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUIHost

/// The frame clock: the browser's display frames, asked for one at a time while held.
/// Design: docs/design/platforms/web/runtime.md#one-frame
@MainActor
final class WebFrameClock: FrameClock {
    /// The runtime's time, in milliseconds on the page's monotonic clock.
    let now: () -> Double

    var onFrame: ((Double) -> Void)?

    var held = false {
        didSet { if held { ask() } }
    }

    /// Whether a frame is asked for and has not come.
    private var asked = false

    /// Whether the browser's frames drive the clock; a test's hand-wound clock takes none.
    private let ticksWithBrowser: Bool

    /// A clock telling `now`'s time: the page's own, or a test's hand-wound one.
    init(now: @escaping () -> Double = { WebRelay.now }, ticksWithBrowser: Bool = true) {
        self.now = now
        self.ticksWithBrowser = ticksWithBrowser
        guard ticksWithBrowser else { return }
        WebRelay.onFrame = { [weak self] time in self?.frame(at: time) }
    }

    private func frame(at time: Double) {
        asked = false
        guard held else { return }
        onFrame?(time)
        if held { ask() }
    }

    private func ask() {
        guard ticksWithBrowser, !asked else { return }
        asked = true
        WebRelay.requestFrame()
    }
}
