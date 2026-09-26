// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension WinUIRegistrations {
    /// A Label: a `TextBlock` - its words, how they break and stand across it, and the space between the letters and
    /// the lines.
    static func text(_ registry: Registry<WinUIView>) {
        registry.add(LabelContract.self, create: { _ in WinUILabelView() }) { label in
            label.applies(TextMembers.members) { view, values in applyText(view, values) }
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

    /// Puts the text tiers' members (`TextMembers`) on a label, a button or a radio button: the words in their case,
    /// the font and the colour, and the room around them.
    static func applyText<Realized: ElementContract>(_ view: WinUIView, _ values: ElementValues<Realized>) {
        if let words = TextMembers.words(values) { (view as? WinUIWordsView)?.setText(words) }
        if let look = TextMembers.look(values) {
            if let text = view as? WinUITextView {
                text.setTextFont(size: look.size, attributes: look.attributes, family: look.family)
            } else {
                view.setFont(size: look.size, attributes: look.attributes, family: look.family)
            }
            view.setForeground(look.color)
        }
        if values.changed(PaddingElementContract.padding) {
            view.setPadding(values[PaddingElementContract.padding])
        }
    }
}
