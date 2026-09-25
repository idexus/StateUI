// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

extension WinUIRegistrations {
    /// A Label: a `TextBlock` - its words, how they break and stand across it, and the space between the letters and
    /// the lines.
    static func text(_ registry: Registry<WinUIView>) {
        registry.add(LabelContract.self, create: { _ in WinUILabelView() }) { label in
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
                view.setLetterSpacing(spacing ?? 0)
            }
            label.property(LineHeightElementContract.lineHeight) { view, height in view.setLineHeight(height) }
            label.property(DecorableTextElementContract.textDecorations) { view, decorations in
                view.setDecorations(decorations)
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

    /// Puts `textMembers` on a label, a button or a radio button.
    static func applyText<Realized: ElementContract>(_ view: WinUIView, _ values: ElementValues<Realized>) {
        if values.changed(TextElementContract.text) || values.changed(TextElementContract.textCase) {
            let words = cased(values[TextElementContract.text] ?? "", values[TextElementContract.textCase])
            (view as? WinUIWordsView)?.setText(words)
        }
        if values.changed(FontElementContract.fontSize) || values.changed(FontElementContract.fontAttributes)
            || values.changed(FontElementContract.fontFamily) {
            let size = values[FontElementContract.fontSize]
            let attributes = values[FontElementContract.fontAttributes]
            let family = values[FontElementContract.fontFamily]?.text
            if let text = view as? WinUITextView {
                text.setTextFont(size: size, attributes: attributes, family: family)
            } else {
                view.setFont(size: size, attributes: attributes, family: family)
            }
        }
        if values.changed(TextStyleElementContract.textColor) {
            view.setForeground(values[TextStyleElementContract.textColor]?.propValue)
        }
        if values.changed(PaddingElementContract.padding) {
            view.setPadding(values[PaddingElementContract.padding])
        }
    }
}
