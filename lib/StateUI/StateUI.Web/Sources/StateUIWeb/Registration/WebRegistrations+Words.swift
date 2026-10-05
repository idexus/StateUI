// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension WebRegistrations {
    /// A Text and a Button: their words in their case, their font and colour and the room around them; a button's
    /// box, whether it takes a click, and the click.
    static func words(_ registry: Registry<WebDOMView>) {
        registry.add(TextContract.self, create: { _ in WebTextView() }) { text in
            text.applies(TextMembers.members) { view, values in applyWords(view, values) }
        }

        registry.add(ButtonContract.self, create: { reports in
            let button = WebButtonView()
            button.onClicked = { reports.raise(ButtonContract.clicked) }
            return button
        }, members: { button in
            button.applies(TextMembers.members) { view, values in applyWords(view, values) }
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
        })
    }

    /// Puts the text tiers' members (`TextMembers`) on a view showing words.
    static func applyWords<Realized: ElementContract>(_ view: some WebWordsView, _ values: ElementValues<Realized>) {
        if let words = TextMembers.words(values) { view.setText(words) }
        if let look = TextMembers.look(values) { view.setLook(look) }
        if values.changed(PaddingElementContract.padding) { view.setPadding(values[PaddingElementContract.padding]) }
    }
}
