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

    /// The value the stepper stood at before the user's step.
    private var shown = 0.0

    init() {
        super.init(frame: .zero)
        addAction(UIAction { [weak self] _ in
            guard let self else { return }
            // A step lands on its decimals (`ValueArithmetic.landed`).
            let landed = ValueArithmetic.landed(value, from: shown, step: stepValue)
            value = landed
            shown = landed
            onValueChanged?(landed)
        }, for: .valueChanged)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("UIKitStepperView is made in code")
    }

    /// The range, its lower end first, a step that moves (`ValueArithmetic`), and the value where the tree wrote one.
    func apply(value: Double?, minimum: Double, maximum: Double, step: Double) {
        (minimumValue, maximumValue) = ValueArithmetic.range(minimum, maximum)
        stepValue = ValueArithmetic.step(step)
        if let value { self.value = value }
        shown = self.value
    }
}
#endif
