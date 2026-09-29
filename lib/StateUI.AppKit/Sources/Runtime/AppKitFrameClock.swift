// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
import QuartzCore
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The frame clock: the display link of the window shown first, moved on when that window closes.
/// Design: docs/design/host/runtime.md#one-frame
@MainActor
final class AppKitFrameClock: NSObject, FrameClock {
    /// The runtime's time, in milliseconds on one monotonic clock.
    let now: () -> Double

    /// What a frame of the display does, handed that frame's time.
    var onFrame: ((Double) -> Void)?

    /// Whether something holds the clock. Frames come only while it does.
    var held = false {
        didSet { link?.isPaused = !held }
    }

    /// Whether frames are coming: a window's display, held.
    var isRunning: Bool { link.map { !$0.isPaused } ?? false }

    /// The window whose display gives the frames.
    private(set) weak var window: NSWindow?

    private var link: CADisplayLink?

    /// A clock on `now` (the displays' own milliseconds by default), silent until a window attaches.
    init(now: @escaping () -> Double = { CACurrentMediaTime() * 1_000 }) {
        self.now = now
    }

    /// Takes the frames of `window`'s display, unless a display already gives them.
    func attach(to window: NSWindow) {
        guard link == nil else { return }

        let link = window.displayLink(target: self, selector: #selector(frame(_:)))
        link.add(to: .main, forMode: .common)
        link.isPaused = !held
        self.link = link
        self.window = window
    }

    /// Moves the frames off a closing window, to `next` when one remains.
    func release(_ closing: NSWindow, next: NSWindow?) {
        guard window === closing else { return }

        stop()
        if let next { attach(to: next) }
    }

    /// Stops the frames for good.
    func stop() {
        link?.invalidate()
        link = nil
        window = nil
    }

    @objc private func frame(_ link: CADisplayLink) {
        onFrame?(link.timestamp * 1_000)
    }
}
#endif
