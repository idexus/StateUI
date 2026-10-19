// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import QuartzCore
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The frame clock: the display's frames by a display link, running only while something holds it.
@MainActor
final class UIKitFrameClock: NSObject, FrameClock {
    /// The runtime's time, in milliseconds on the clock the display's frames are stamped on.
    let now: () -> Double

    /// What a frame of the display does, handed that frame's time.
    var onFrame: ((Double) -> Void)?

    /// Whether something holds the clock. Frames come only while it does.
    var held = false {
        didSet { link?.isPaused = !held }
    }

    private(set) var link: CADisplayLink?

    /// A clock telling `now`'s time, its frames the display's where `ticksWithTheDisplay`.
    init(now: @escaping () -> Double = { CACurrentMediaTime() * 1_000 }, ticksWithTheDisplay: Bool = true) {
        self.now = now
        super.init()
        guard ticksWithTheDisplay else { return }
        let link = CADisplayLink(target: self, selector: #selector(frame(_:)))
        link.preferredFrameRateRange = Self.fullRate
        link.isPaused = true
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    /// The display's own rate: a motion asks every frame a ProMotion display draws, which an iPhone gives only to an
    /// application whose `Info.plist` says `CADisableMinimumFrameDurationOnPhone`.
    /// Design: docs/design/platforms/uikit/runtime.md#the-frame-clock
    static let fullRate = CAFrameRateRange(minimum: 80, maximum: 120, preferred: 120)

    /// Lets the display go - a display link holds its clock until then - so no frame comes after.
    func stop() {
        link?.invalidate()
        link = nil
    }

    @objc private func frame(_ link: CADisplayLink) {
        guard held else { return }
        onFrame?(link.timestamp * 1_000)
    }
}
#endif
