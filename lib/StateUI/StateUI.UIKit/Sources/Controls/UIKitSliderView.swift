// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A Slider: UIKit's own. The user's moves are reported as they go, and a hand's taking and letting go of the
/// thumb; the program's value is only shown.
@MainActor
final class UIKitSliderView: UISlider {
    var onValueChanged: ((Double) -> Void)?
    var onDragStarted: (() -> Void)?
    var onDragCompleted: (() -> Void)?

    init() {
        super.init(frame: .zero)
        addAction(UIAction { [weak self] _ in
            guard let self else { return }
            onValueChanged?(Double(value))
        }, for: .valueChanged)
        addAction(UIAction { [weak self] _ in self?.onDragStarted?() }, for: .touchDown)
        addAction(UIAction { [weak self] _ in self?.onDragCompleted?() }, for: [.touchUpInside, .touchUpOutside])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("UIKitSliderView is made in code")
    }

    /// The range, its lower end first (`ValueArithmetic.range`), and the value where the tree wrote one.
    func apply(value: Double?, minimum: Double, maximum: Double) {
        let (lower, upper) = ValueArithmetic.range(minimum, maximum)
        (minimumValue, maximumValue) = (Float(lower), Float(upper))
        if let value { self.value = Float(value) }
    }
}
#endif
