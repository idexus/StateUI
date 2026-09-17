// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit

/// A native continuous slider with explicit boundaries between StateUI writes
/// and values moved by the reader.
@MainActor
final class AppKitSliderView: NSSlider {
    var onValueChanged: ((Double) -> Void)?
    var onDragStarted: (() -> Void)?
    var onDragCompleted: (() -> Void)?

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

    /// Applies the StateUI range before its value so AppKit clamps only against
    /// the current range. Reversed endpoints describe the same closed interval.
    func apply(
        value: Double?,
        writeValue: Bool,
        minimum: Double,
        maximum: Double,
        tint: NSColor?,
        enabled: Bool
    ) {
        minValue = min(minimum, maximum)
        maxValue = max(minimum, maximum)
        trackFillColor = tint
        isEnabled = enabled

        if writeValue, let value {
            setValue(value)
        }
    }

    /// Writes a value from StateUI without turning it into a reader report.
    func setValue(_ value: Double) {
        doubleValue = min(max(value, minValue), maxValue)
    }

    @objc func valueChanged(_ sender: NSSlider) {
        onValueChanged?(sender.doubleValue)
    }

    override func mouseDown(with event: NSEvent) {
        beginDrag()
        super.mouseDown(with: event)
        endDrag()
    }

    func beginDrag() {
        onDragStarted?()
    }

    func endDrag() {
        onDragCompleted?()
    }
}

#endif
