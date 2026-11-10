// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A ColorPicker: UIKit's color well, which presents the system's color picker; each color the user chooses there is
/// reported as the host layer reports it, and the program's only shown.
/// Design: docs/design/platforms/uikit/controls.md#a-color-picker
@MainActor
final class UIKitColorPickerView: UIColorWell, UIKitAccessibilityAuthoring {
    /// What the well does as the user chooses a color.
    var onChosen: ((Color) -> Void)?

    /// What the tree says of it for VoiceOver, answered before UIKit's own.
    var authored = UIKitAuthoredAccessibility()

    override var accessibilityLabel: String? {
        get { authored.label ?? super.accessibilityLabel }
        set { super.accessibilityLabel = newValue }
    }

    override var accessibilityHint: String? {
        get { authored.hint ?? super.accessibilityHint }
        set { super.accessibilityHint = newValue }
    }

    override var accessibilityValue: String? {
        get { authored.value ?? super.accessibilityValue }
        set { super.accessibilityValue = newValue }
    }

    override var accessibilityTraits: UIAccessibilityTraits {
        get { authored.traits(over: super.accessibilityTraits) }
        set { super.accessibilityTraits = newValue }
    }

    override var isAccessibilityElement: Bool {
        get { authored.isElement ?? super.isAccessibilityElement }
        set { super.isAccessibilityElement = newValue }
    }

    override var accessibilityElementsHidden: Bool {
        get { authored.hidesItsElements || super.accessibilityElementsHidden }
        set { super.accessibilityElementsHidden = newValue }
    }

    init() {
        super.init(frame: .zero)
        addAction(UIAction { [weak self] _ in
            guard let self, let chosen = selectedColor else { return }
            var (red, green, blue, alpha): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
            chosen.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            onChosen?(ColorChoice.reported(
                (Double(red), Double(green), Double(blue), Double(alpha)), choosesOpacity: supportsAlpha))
        }, for: .valueChanged)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("UIKitColorPickerView is made in code")
    }

    /// The color it shows where `write` says the tree changed it, and whether the picker offers opacity.
    func apply(color: Color, write: Bool, choosesOpacity: Bool) {
        supportsAlpha = choosesOpacity
        if write { selectedColor = UIColor(stateUI: color.propValue) ?? .black }
    }
}
#endif
