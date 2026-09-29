// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUIHost

/// AppKit's exact-step numeric input with one report per settled step.
@MainActor
final class AppKitStepperView: NSStepper {
    var onValueChanged: ((Double) -> Void)?

    /// The value the stepper stood at before a click.
    private var shown = 0.0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        valueWraps = false
        autorepeat = true
        target = self
        action = #selector(changed(_:))
    }

    convenience init() {
        self.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppKitStepperView is created in code")
    }

    /// Applies the range and the step before the value, so AppKit clamps only against the range it has now.
    func apply(value: Double, minimum: Double, maximum: Double, step: Double, enabled: Bool) {
        (minValue, maxValue) = ValueArithmetic.range(minimum, maximum)
        increment = ValueArithmetic.step(step)
        isEnabled = enabled
        doubleValue = min(max(value, minValue), maxValue)
        shown = doubleValue
    }

    /// A click at an end moves nothing, and nobody hears it.
    @objc private func changed(_ sender: NSStepper) {
        guard sender.doubleValue != shown else { return }
        shown = sender.doubleValue
        onValueChanged?(sender.doubleValue)
    }

    func stepForTesting(to value: Double) {
        doubleValue = value
        changed(self)
    }
}

#endif
