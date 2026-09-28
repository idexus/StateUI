// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension GTKRegistrations {
    /// A Label: a `GtkLabel` - its words, how they break and stand across and down it, the space between the
    /// letters and the lines, and what fills its box.
    static func text(_ registry: Registry<GTKView>) {
        registry.add(LabelContract.self, create: { _ in GTKLabelView() }) { label in
            label.applies(TextMembers.members) { view, values in applyText(view, values) }
            label.applies([LabelContract.lineBreak, LabelContract.maximumLines]) { view, values in
                view.setLines(
                    breaking: values[LabelContract.lineBreak] ?? .wordWrap,
                    maximum: values[LabelContract.maximumLines])
            }
            label.property(TextAlignmentElementContract.horizontalTextAlignment) { view, alignment in
                view.setAlignment(horizontal: alignment ?? .start)
            }
            label.property(TextAlignmentElementContract.verticalTextAlignment) { view, alignment in
                view.setAlignment(vertical: alignment ?? .start)
            }
            label.property(VisualElementContract.background) { view, background in
                view.setBackground(background?.propValue)
            }
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

    /// Puts the text tiers' members (`TextMembers`) on a label, a button or a radio button: the words in their case,
    /// the font and the colour, and the room around them.
    static func applyText<Realized: ElementContract>(_ view: any GTKWordsView, _ values: ElementValues<Realized>) {
        if let words = TextMembers.words(values) { view.setText(words) }
        if let look = TextMembers.look(values) {
            view.setLook { shown in
                shown.size = look.size
                shown.attributes = look.attributes
                shown.family = look.family
                shown.color = look.color
            }
        }
        if values.changed(PaddingElementContract.padding) {
            view.setPadding(values[PaddingElementContract.padding])
        }
    }
}
