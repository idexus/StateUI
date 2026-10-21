// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension UIKitRegistrations {
    /// A Text: its words in their case, or its spans' runs; their look, the space between the letters and the
    /// lines, and the lines under or through them; how they break and where they stand; the room around them.
    static func text(_ registry: Registry<UIView>) {
        // Words the user selects stand in a text view, others in a label: another value makes the text anew.
        registry.add(TextContract.self, create: { reports -> UIView in
            reports.made?.properties[.isSelectable] == .bool(true) ? UIKitSelectableTextView() : UIKitTextView()
        }) { (label: Registration<TextContract, UIView>) in
            label.applies(TextMembers.members) { view, values in
                let view = view as! any UIKitLabel
                if let words = TextMembers.words(values) { view.setText(words) }
                if let look = TextMembers.look(values) {
                    view.setLook { $0.adopt(fontAndColorOf: look) }
                }
                if values.changed(PaddingElementContract.padding) {
                    view.setPadding(values[PaddingElementContract.padding])
                }
            }
            label.applies(TextContract.lineBreak, TextContract.maximumLines) { view, values in
                (view as! any UIKitLabel).setLines(
                    breaking: values[TextContract.lineBreak] ?? .wordWrap, maximum: values[TextContract.maximumLines])
            }
            label.applies(
                TextAlignmentElementContract.horizontalTextAlignment,
                TextContract.verticalTextAlignment) { view, values in
                (view as! any UIKitLabel).setAlignment(
                    horizontal: values[TextAlignmentElementContract.horizontalTextAlignment] ?? .start,
                    vertical: values[TextContract.verticalTextAlignment] ?? .start)
            }
            label.property(VisualElementContract.isEnabled) { view, enabled in
                (view as! any UIKitLabel).isEnabled = enabled ?? true
            }
            label.property(VisualElementContract.background) { view, background in
                (view as! any UIKitLabel).setBackground(background?.propValue)
            }
            label.property(TrackingElementContract.tracking) { view, spacing in
                (view as! any UIKitLabel).setLook { $0.letterSpacing = spacing ?? 0 }
            }
            label.property(LineHeightElementContract.lineHeight) { view, height in
                (view as! any UIKitLabel).setLook { $0.lineHeight = height }
            }
            label.property(DecorableTextElementContract.textDecorations) { view, decorations in
                (view as! any UIKitLabel).setLook { $0.decorations = decorations ?? .none }
            }
        }
    }
}
#endif
