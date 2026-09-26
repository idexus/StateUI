// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension AndroidRegistrations {
    /// A Label: a `TextView` - its words, how they break and stand, and the space between the letters.
    /// Runs of words in a label's spans are its element's to lay down, as its children.
    static func text(_ registry: Registry<AndroidView>) {
        registry.add(LabelContract.self, create: { _ in AndroidLabelView() }) { label in
            label.applies(textMembers) { view, values in applyText(view, values) }
            label.applies([LabelContract.lineBreak, LabelContract.maximumLines]) { view, values in
                view.setLines(
                    breaking: values[LabelContract.lineBreak] ?? .wordWrap,
                    maximum: values[LabelContract.maximumLines])
            }
            label.applies([
                TextAlignmentElementContract.horizontalTextAlignment,
                TextAlignmentElementContract.verticalTextAlignment,
            ]) { view, values in
                view.setAlignment(
                    horizontal: values[TextAlignmentElementContract.horizontalTextAlignment] ?? .start,
                    vertical: values[TextAlignmentElementContract.verticalTextAlignment] ?? .start)
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
}
