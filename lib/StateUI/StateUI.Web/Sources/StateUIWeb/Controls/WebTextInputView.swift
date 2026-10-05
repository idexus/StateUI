// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A TextField, a SearchField and a TextEditor: the browser's `<input>`, its search `<input>` and its `<textarea>`,
/// each reporting every change of its words, and a field the Return key.
/// Design: docs/design/platforms/web/controls.md#a-field
@MainActor
final class WebTextInputView: WebDOMView, WebWordsView {
    /// Which of the three the view is.
    enum Kind {
        case field, search, editor
    }

    let kind: Kind

    /// The user changed the words, which it is handed.
    var onTextChanged: (String) -> Void = { _ in }

    /// The user pressed Return in a field.
    var onSubmitted: () -> Void = {}

    /// Whether an editor grows with its words rather than scrolling them.
    private var grows = false

    init(_ kind: Kind) {
        self.kind = kind
        super.init(tag: kind == .editor ? "textarea" : "input")
        if kind != .editor {
            attribute("type", kind == .search ? "search" : "text")
            attribute("class", "stateui-field")
        }
        listen("input") { [weak self] in
            guard let self else { return }
            fit()
            onTextChanged(WebRelay.value(of: node))
        }
        if kind != .editor { listen("enter") { [weak self] in self?.onSubmitted() } }
    }

    override var role: String? { nil }

    override var isControl: Bool { true }

    /// The words the field holds; the relay leaves the user's caret where it stands when they are the same.
    func setText(_ text: String) {
        WebRelay.setValue(node, text)
        fit()
    }

    override func setEnabled(_ enabled: Bool) {
        attribute("disabled", enabled ? nil : "")
    }

    func setPlaceholder(_ placeholder: String?) {
        self.placeholder = placeholder ?? ""
        attribute("placeholder", placeholder)
        fit()
    }

    /// The words shown while there are none, which a field's natural width counts too.
    private var placeholder = ""

    /// The colour of the words shown while there are none; nil for the page's.
    func setPlaceholderColor(_ color: HostValue?) {
        style("--stateui-placeholder", WebCSS.color(color))
    }

    /// The most characters the field takes; nil for no bound.
    func setMaximumLength(_ length: Int?) {
        attribute("maxlength", length.map(String.init))
    }

    /// Whether a field hides its words, as a password's.
    func setPassword(_ hidden: Bool) {
        guard kind == .field else { return }
        attribute("type", hidden ? "password" : "text")
    }

    func setReadOnly(_ readOnly: Bool) {
        attribute("readonly", readOnly ? "" : nil)
    }

    /// The keyboard and the help the user's typing gets, by the host layer's traits.
    /// Design: docs/design/platforms/web/controls.md#a-field
    func setTraits(_ traits: InputTraits) {
        let mode: String? = switch traits.keys {
        case .words: nil
        case .email: "email"
        case .number: "decimal"
        case .telephone: "tel"
        case .url: "url"
        }
        attribute("inputmode", mode)
        attribute("autocapitalize", traits.capitals == .none ? "off" : traits.capitals == .sentences ? "sentences" : nil)
        attribute("spellcheck", traits.checksSpelling ? "true" : "false")
        attribute("autocorrect", traits.corrects ? "on" : "off")
        attribute("autocomplete", traits.predicts ? nil : "off")
    }

    /// What the keyboard's Return key says.
    func setSubmitLabel(_ label: SubmitLabel) {
        let hint: String? = switch label {
        case .default: nil
        case .done: "done"
        case .go: "go"
        case .next: "next"
        case .search: "search"
        case .send: "send"
        }
        attribute("enterkeyhint", hint)
    }

    func setAlignment(_ alignment: TextAlignment) {
        style("text-align", alignment == .center ? "center" : alignment == .end ? "end" : nil)
    }

    /// Puts the caret `start` characters in and selects `length` from it.
    func select(start: Int, length: Int) {
        let words = WebRelay.value(of: node)
        let from = words.prefix(max(0, start))
        let selected = words.dropFirst(from.count).prefix(max(0, length))
        WebRelay.select(node, from: from.utf16.count, length: selected.utf16.count)
    }

    /// Whether an editor grows with its words.
    func setGrowsWithText(_ grows: Bool) {
        self.grows = grows
        style("overflow", grows ? "hidden" : nil)
        style("resize", grows ? "none" : nil)
        fit()
    }

    /// An editor growing with its words stands as tall as they are.
    private func fit() {
        // A field is as wide as its words or its placeholder, not the browser's twenty characters: where the browser
        // sizes no field by its content, the characters it counts say it.
        if kind != .editor {
            return attribute("size", String(max(1, WebRelay.value(of: node).count, placeholder.count)))
        }
        guard grows else { return }
        style("height", nil)
        style("height", WebCSS.pixels(WebRelay.number(of: node, "scrollHeight")))
    }
}
