// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit

/// What the tree says of one of UIKit's own controls for VoiceOver, kept by the control so it answers it first: UIKit's
/// accessibility bundles, loaded wherever VoiceOver runs, answer for UIKit's controls over what is set on them. What
/// the tree leaves unsaid is the control's own.
/// Design: docs/design/platforms/uikit/controls.md#accessibility
struct UIKitAuthoredAccessibility {
    var label: String?
    var hint: String?
    var value: String?

    /// The kind said, which stands in place of the control's own kinds; nil keeps them.
    var kind: UIAccessibilityTraits?

    var isHeading = false
    var isElement: Bool?
    var hidesItsElements = false

    /// The traits VoiceOver meets: the control's `own`, the kind said in place of its kinds, a heading where said.
    @MainActor func traits(over own: UIAccessibilityTraits) -> UIAccessibilityTraits {
        var traits = kind.map { own.subtracting(UIKitElement.kinds).union($0) } ?? own
        if isHeading { traits.insert(.header) } else { traits.remove(.header) }
        return traits
    }
}
#endif
