// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension UIKitRegistrations {
    /// A Label: its words in their case, or its spans' runs; their look, the space between the letters and the
    /// lines, and the lines under or through them; how they break and where they stand; the room around them.
    static func text(_ registry: Registry<UIView>) {
        registry.add(LabelContract.self, create: { _ in UIKitLabelView() }) { label in
            label.applies(TextMembers.members) { view, values in
                if let words = TextMembers.words(values) { view.setText(words) }
                if let look = TextMembers.look(values) {
                    view.setLook { shown in
                        (shown.size, shown.attributes, shown.family, shown.color) =
                            (look.size, look.attributes, look.family, look.color)
                    }
                }
                if values.changed(PaddingElementContract.padding) {
                    view.setPadding(values[PaddingElementContract.padding])
                }
            }
            label.applies([LabelContract.lineBreak, LabelContract.maximumLines]) { view, values in
                view.setLines(
                    breaking: values[LabelContract.lineBreak] ?? .wordWrap, maximum: values[LabelContract.maximumLines])
            }
            label.applies([
                TextAlignmentElementContract.horizontalTextAlignment,
                TextAlignmentElementContract.verticalTextAlignment,
            ]) { view, values in
                view.setAlignment(
                    horizontal: values[TextAlignmentElementContract.horizontalTextAlignment] ?? .start,
                    vertical: values[TextAlignmentElementContract.verticalTextAlignment] ?? .start)
            }
            label.property(VisualElementContract.isEnabled) { view, enabled in view.isEnabled = enabled ?? true }
            label.property(TextStyleElementContract.characterSpacing) { view, spacing in
                view.setLook { $0.letterSpacing = spacing ?? 0 }
            }
            label.property(LineHeightElementContract.lineHeight) { view, height in
                view.setLook { $0.lineHeight = height }
            }
            label.property(DecorableTextElementContract.textDecorations) { view, decorations in
                view.setLook { $0.decorations = decorations ?? .none }
            }
        }
    }
}
#endif
