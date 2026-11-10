// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit

/// UIKit's switch, answering VoiceOver with what the tree says before its own.
/// Design: docs/design/platforms/uikit/controls.md#accessibility
@MainActor
final class UIKitSwitchControl: UISwitch, UIKitAccessibilityAuthoring {
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
}
#endif
