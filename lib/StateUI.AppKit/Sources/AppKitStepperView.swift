// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit

/// AppKit's exact-step numeric input with one report per settled step.
@MainActor
final class AppKitStepperView: NSStepper {
    var onValueChanged: ((Double) -> Void)?

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

    func apply(
        value: Double?,
        writeValue: Bool,
        minimum: Double,
        maximum: Double,
        increment: Double,
        enabled: Bool
    ) {
        minValue = min(minimum, maximum)
        maxValue = max(minimum, maximum)
        self.increment = increment.isFinite && increment > 0 ? increment : 1
        isEnabled = enabled

        if writeValue, let value {
            doubleValue = min(max(value, minValue), maxValue)
        }
    }

    @objc private func changed(_ sender: NSStepper) {
        onValueChanged?(sender.doubleValue)
    }

    func stepForTesting(to value: Double) {
        doubleValue = value
        changed(self)
    }
}

#endif
