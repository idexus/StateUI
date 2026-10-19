// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUIHost

/// A native continuous slider with explicit boundaries between StateUI writes
/// and values moved by the user.
@MainActor
final class AppKitSliderView: NSSlider {
    var onValueChanged: ((Double) -> Void)?
    var onPressed: (() -> Void)?
    var onReleased: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        sliderType = .linear
        isContinuous = true
        target = self
        action = #selector(valueChanged(_:))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppKitSliderView is created in code")
    }

    /// Applies the range before the value, so AppKit clamps only against the range it has now.
    func apply(value: Double, minimum: Double, maximum: Double, tint: NSColor?, enabled: Bool) {
        (minValue, maxValue) = ValueArithmetic.range(minimum, maximum)
        trackFillColor = tint
        isEnabled = enabled
        setValue(value)
    }

    /// Writes a value from StateUI without turning it into a user report.
    func setValue(_ value: Double) {
        doubleValue = min(max(value, minValue), maxValue)
    }

    @objc func valueChanged(_ sender: NSSlider) {
        onValueChanged?(sender.doubleValue)
    }

    /// The keys move the thumb as on every host: an arrow a hundredth of the range, a page key a tenth
    /// (`ValueArithmetic.sliderSteps`), each move the user's.
    /// Design: docs/design/platforms/appkit/input.md#a-slider-and-its-keys
    override func moveRight(_ sender: Any?) { step(by: steps.key, forward: true) }
    override func moveLeft(_ sender: Any?) { step(by: -steps.key, forward: true) }
    override func moveUp(_ sender: Any?) { step(by: steps.key, forward: false) }
    override func moveDown(_ sender: Any?) { step(by: -steps.key, forward: false) }
    override func pageUp(_ sender: Any?) { step(by: steps.page, forward: false) }
    override func pageDown(_ sender: Any?) { step(by: -steps.page, forward: false) }

    private var steps: (key: Double, page: Double) { ValueArithmetic.sliderSteps(lower: minValue, upper: maxValue) }

    /// Moves the thumb by `amount` within the range and says it as the user's; a horizontal arrow follows the
    /// direction the layout reads in.
    private func step(by amount: Double, forward: Bool) {
        guard isEnabled else { return }
        let way = forward && userInterfaceLayoutDirection == .rightToLeft ? -amount : amount
        let moved = min(max(doubleValue + way, minValue), maxValue)
        guard moved != doubleValue else { return }
        doubleValue = moved
        sendAction(action, to: target)
    }

    override func mouseDown(with event: NSEvent) {
        beginDrag()
        super.mouseDown(with: event)
        endDrag()
    }

    func beginDrag() {
        onPressed?()
    }

    func endDrag() {
        onReleased?()
    }
}

#endif
