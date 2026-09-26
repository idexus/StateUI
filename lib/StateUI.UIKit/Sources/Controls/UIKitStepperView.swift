// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A Stepper: UIKit's own pair of buttons. The user's step is reported; the program's value is only shown.
@MainActor
final class UIKitStepperView: UIStepper {
    var onValueChanged: ((Double) -> Void)?

    init() {
        super.init(frame: .zero)
        addAction(UIAction { [weak self] _ in
            guard let self else { return }
            onValueChanged?(value)
        }, for: .valueChanged)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("UIKitStepperView is made in code")
    }

    /// The range and the step, and the value where the tree wrote one.
    func apply(value: Double?, minimum: Double, maximum: Double, step: Double) {
        minimumValue = minimum
        maximumValue = max(minimum, maximum)
        stepValue = step > 0 ? step : 1
        if let value { self.value = value }
    }
}
#endif
