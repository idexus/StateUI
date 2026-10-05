// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A TextField: the browser's `<input>`, reporting each change of its words and the Return key.
/// Design: docs/design/platforms/web/controls.md#a-field
@MainActor
final class WebTextFieldView: WebDOMView, WebWordsView {
    /// The user changed the words, which it is handed.
    var onTextChanged: (String) -> Void = { _ in }

    /// The user pressed Return.
    var onSubmitted: () -> Void = {}

    init() {
        super.init(tag: "input")
        attribute("type", "text")
        listen("input") { [weak self] in
            guard let self else { return }
            onTextChanged(WebRelay.value(of: node))
        }
        listen("enter") { [weak self] in self?.onSubmitted() }
    }

    /// The words the field holds; the relay leaves the user's caret where it stands when they are the same.
    func setText(_ text: String) {
        WebRelay.setValue(node, text)
    }

    override func setEnabled(_ enabled: Bool) {
        attribute("disabled", enabled ? nil : "")
    }

    func setPlaceholder(_ placeholder: String?) {
        attribute("placeholder", placeholder)
    }

    /// The most characters the field takes; nil for no bound.
    func setMaximumLength(_ length: Int?) {
        attribute("maxlength", length.map(String.init))
    }

    /// Whether the field hides its words, as a password's.
    func setPassword(_ hidden: Bool) {
        attribute("type", hidden ? "password" : "text")
    }

    func setReadOnly(_ readOnly: Bool) {
        attribute("readonly", readOnly ? "" : nil)
    }
}
