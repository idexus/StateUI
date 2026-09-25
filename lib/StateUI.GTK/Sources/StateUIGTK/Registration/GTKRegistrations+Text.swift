// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

extension GTKRegistrations {
    /// A Label: a `GtkLabel` - its words, how they break and stand across it, and the space between the letters and
    /// the lines.
    static func text(_ registry: Registry<GTKView>) {
        registry.add(LabelContract.self, create: { _ in GTKLabelView() }) { label in
            label.applies(textMembers) { view, values in applyText(view, values) }
            label.applies([LabelContract.lineBreak, LabelContract.maximumLines]) { view, values in
                view.setLines(
                    breaking: values[LabelContract.lineBreak] ?? .wordWrap,
                    maximum: values[LabelContract.maximumLines])
            }
            label.property(TextAlignmentElementContract.horizontalTextAlignment) { view, alignment in
                view.setAlignment(horizontal: alignment ?? .start)
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

    /// What every element showing words takes: the words in their case, the font, their colour, and the room
    /// around them.
    static let textMembers: [any ContractMember] = [
        TextElementContract.text, TextElementContract.textCase, FontElementContract.fontSize,
        FontElementContract.fontAttributes, FontElementContract.fontFamily, TextStyleElementContract.textColor,
        PaddingElementContract.padding,
    ]

    /// Puts `textMembers` on a label or a button.
    static func applyText<Realized: ElementContract>(_ view: any GTKWordsView, _ values: ElementValues<Realized>) {
        if values.changed(TextElementContract.text) || values.changed(TextElementContract.textCase) {
            let text = values[TextElementContract.text] ?? ""
            view.setText(values[TextElementContract.textCase]?.applied(to: text) ?? text)
        }
        if values.changed(FontElementContract.fontSize) || values.changed(FontElementContract.fontAttributes)
            || values.changed(FontElementContract.fontFamily) || values.changed(TextStyleElementContract.textColor) {
            view.setLook { look in
                look.size = values[FontElementContract.fontSize]
                look.attributes = values[FontElementContract.fontAttributes] ?? .none
                look.family = values[FontElementContract.fontFamily]?.text
                look.color = values[TextStyleElementContract.textColor]?.propValue
            }
        }
        if values.changed(PaddingElementContract.padding) {
            view.setPadding(values[PaddingElementContract.padding])
        }
    }
}
