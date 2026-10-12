// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit

/// A view's tooltip: UIKit's tool tip interaction, shown where a pointer rests on the view - an iPad's - added with
/// the first words and taken away with the last.
/// Design: docs/design/views/modifiers.md#a-tooltip
extension UIView {
    var tooltip: String? {
        get { tooltipInteraction?.defaultToolTip }
        set {
            if let newValue {
                if let held = tooltipInteraction {
                    held.defaultToolTip = newValue
                } else {
                    addInteraction(UIToolTipInteraction(defaultToolTip: newValue))
                }
            } else if let held = tooltipInteraction {
                removeInteraction(held)
            }
        }
    }

    private var tooltipInteraction: UIToolTipInteraction? {
        interactions.lazy.compactMap { $0 as? UIToolTipInteraction }.first
    }
}
#endif
