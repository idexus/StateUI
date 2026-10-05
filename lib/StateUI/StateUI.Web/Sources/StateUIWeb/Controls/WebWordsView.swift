// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A view showing words in a look: a text, a button.
@MainActor
protocol WebWordsView: WebDOMView {
    func setText(_ text: String)
}

extension WebWordsView {
    func setText(_ text: String) {
        WebRelay.setText(node, text)
    }

    /// The words' font and colour; what the look leaves unsaid is the page's.
    /// Design: docs/design/platforms/web/controls.md#words
    func setLook(_ look: TextLook) {
        for (name, value) in WebCSS.font(look) { style(name, value) }
    }
}
