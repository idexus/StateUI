// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension WebRegistrations {
    /// A Text and a Button: their words in their case, their font and colour and the room around them; a text's
    /// lines, alignment, spacing and decorations; a button's picture, its lines, its spacing, its box, whether it
    /// takes a click, and the click.
    static func words(_ registry: Registry<WebDOMView>) {
        registry.add(TextContract.self, create: { _ in WebTextView() }) { text in
            text.applies(TextMembers.members) { view, values in applyWords(view, values) }
            text.applies([TextContract.lineBreak, TextContract.maximumLines]) { view, values in
                view.setLines(breaking: values[TextContract.lineBreak] ?? .wordWrap, maximum: values[TextContract.maximumLines])
            }
            text.property(TextAlignmentElementContract.horizontalTextAlignment) { view, alignment in
                view.setAlignment(horizontal: alignment ?? .start)
            }
            text.property(TextAlignmentElementContract.verticalTextAlignment) { view, alignment in
                view.setAlignment(vertical: alignment ?? .start)
            }
            text.applies([
                TextStyleElementContract.tracking, LineHeightElementContract.lineHeight,
                DecorableTextElementContract.textDecorations,
            ]) { view, values in
                var look = TextLook()
                look.letterSpacing = values[TextStyleElementContract.tracking] ?? 0
                look.lineHeight = values[LineHeightElementContract.lineHeight]
                look.decorations = values[DecorableTextElementContract.textDecorations] ?? .none
                view.setSpacing(look)
            }
        }

        registry.add(ButtonContract.self, create: { reports in
            let button = WebButtonView()
            button.onClicked = { reports.raise(ButtonContract.clicked) }
            button.listenForHolding(
                pressed: { reports.raise(ButtonContract.pressed) }, released: { reports.raise(ButtonContract.released) })
            return button
        }, members: { button in
            button.applies(TextMembers.members) { view, values in applyWords(view, values) }
            button.applies([
                ButtonContract.icon, ButtonContract.iconPosition, ButtonContract.iconSpacing,
                ImageElementContract.contentMode,
            ]) { view, values in
                view.setIcon(
                    values[ButtonContract.icon], position: values[ButtonContract.iconPosition] ?? .leading,
                    spacing: values[ButtonContract.iconSpacing], aspect: values[ImageElementContract.contentMode] ?? .fit)
            }
            button.property(ButtonContract.lineBreak) { view, lineBreak in view.setLines(lineBreak) }
            button.property(TextStyleElementContract.tracking) { view, spacing in
                view.style("letter-spacing", WebCSS.letterSpacing(spacing ?? 0))
            }
            button.applies([
                VisualElementContract.background,
                BorderElementContract.shape, BorderElementContract.stroke, BorderElementContract.lineWidth,
            ]) { view, values in
                view.setBox(
                    fill: values[VisualElementContract.background]?.propValue,
                    stroke: values[BorderElementContract.stroke]?.propValue,
                    lineWidth: values[BorderElementContract.lineWidth],
                    shape: values[BorderElementContract.shape]?.propValue)
            }
            button.property(VisualElementContract.isEnabled) { view, enabled in view.setEnabled(enabled ?? true) }
            button.raises(ButtonContract.clicked)
            button.raises(ButtonContract.pressed)
            button.raises(ButtonContract.released)
        })
    }

    /// Puts the text tiers' members (`TextMembers`) on a view showing words.
    static func applyWords<Realized: ElementContract>(_ view: some WebWordsView, _ values: ElementValues<Realized>) {
        if let words = TextMembers.words(values) { view.setText(words) }
        if let look = TextMembers.look(values) { view.setLook(look) }
        if values.changed(PaddingElementContract.padding) { view.setPadding(values[PaddingElementContract.padding]) }
    }
}
