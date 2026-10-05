// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUIHost

/// The frame clock: the browser's display frames, asked for one at a time while held.
/// Design: docs/design/platforms/web/runtime.md#one-frame
@MainActor
final class WebFrameClock: FrameClock {
    /// The page's time, in milliseconds on its monotonic clock.
    let now: () -> Double = { WebRelay.now }

    var onFrame: ((Double) -> Void)?

    var held = false {
        didSet { if held { ask() } }
    }

    /// Whether a frame is asked for and has not come.
    private var asked = false

    init() {
        WebRelay.onFrame = { [weak self] time in self?.frame(at: time) }
    }

    private func frame(at time: Double) {
        asked = false
        guard held else { return }
        onFrame?(time)
        if held { ask() }
    }

    private func ask() {
        guard !asked else { return }
        asked = true
        WebRelay.requestFrame()
    }
}
