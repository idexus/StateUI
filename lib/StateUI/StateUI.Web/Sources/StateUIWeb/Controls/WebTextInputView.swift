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

    /// The words the field said or was given last: the browser may say the same words again - a line typed in an
    /// editor is several of its inputs - which change nothing.
    private var said = ""

    init(_ kind: Kind) {
        self.kind = kind
        super.init(tag: kind == .editor ? "textarea" : "input")
        if kind != .editor {
            attribute("type", kind == .search ? "search" : "text")
            attribute("class", "stateui-field")
        }
        listen("input") { [weak self] in self?.typed(composing: WebRelay.eventComposing) }
        // Safari ends a composition after its last input: the words are held as it ends.
        listen("compositionend") { [weak self] in self?.typed(composing: false) }
        if kind != .editor { hear(.enter) { [weak self] in self?.onSubmitted() } }
    }

    override var role: String? { nil }

    override var isControl: Bool { true }

    /// The words the field holds; the relay leaves the user's caret where it stands when they are the same.
    func setText(_ text: String) {
        said = text
        WebRelay.setValue(node, text)
        fit()
    }

    override func setEnabled(_ enabled: Bool) {
        attribute("disabled", enabled ? nil : "")
    }

    /// The outline the tree gives the field - its color and width - and the shape its ground and outline follow, over
    /// the page's own frame; the page's where it gives none. Only the border and the corners: the background
    /// shorthand would clear the picture the page's look draws in a field.
    /// Design: docs/design/platforms/web/look.md#a-fields-outline
    func setOutline(stroke: HostValue?, lineWidth: Double?, shape: HostValue?) {
        let width = BoxArithmetic.outlineWidth(stroke: stroke, width: lineWidth)
        let color = WebCSS.color(HostBrush(stroke).firstColor) ?? "currentColor"
        style("border", stroke == nil ? nil : width > 0 ? "\(WebCSS.pixels(width)!) solid \(color)" : "none")
        style("border-radius", shape == nil ? nil : WebCSS.corners(BoxArithmetic.outline(shape)) ?? "0")
    }

    /// An editor given a ground of its own stands in it with no frame of the page's look, as the platforms' editors
    /// draw none.
    /// Design: docs/design/platforms/web/look.md#a-views-background
    override func setBackground(_ value: HostValue?) {
        super.setBackground(value)
        if kind == .editor { attribute("data-ground", value == nil ? nil : "") }
    }

    func setPlaceholder(_ placeholder: String?) {
        self.placeholder = placeholder ?? ""
        attribute("placeholder", placeholder)
        fit()
    }

    /// The words shown while there are none, which a field's natural width counts too.
    private var placeholder = ""

    /// The color of the words shown while there are none; nil for the page's.
    func setPlaceholderColor(_ color: HostValue?) {
        style("--stateui-placeholder", WebCSS.color(color))
    }

    /// The most characters the field takes; nil for no bound.
    func setMaximumLength(_ length: Int?) {
        maximumLength = length
    }

    /// The most characters the field takes, held as the user types: the browser's own bound counts UTF-16 units.
    private var maximumLength: Int?

    /// The user changed the words: held within `maximumLength` - whole while an input method is `composing` them
    /// (`InputWords.held`) - then handed on where they differ from what the field said.
    private func typed(composing: Bool) {
        var words = WebRelay.value(of: node)
        if let held = InputWords.held(words, in: nil, toBound: maximumLength, composing: composing) {
            words = held
            WebRelay.setValue(node, held)
        }
        guard words != said else { return }
        said = words
        fit()
        onTextChanged(words)
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
        case .digits: "numeric"
        case .telephone: "tel"
        case .url: "url"
        }
        attribute("inputmode", mode)
        attribute("autocapitalize", traits.capitals == .none ? "off" : traits.capitals == .sentences ? "sentences" : nil)
        attribute("spellcheck", traits.checksSpelling ? "true" : "false")
        attribute("autocorrect", traits.corrects ? "on" : "off")
        // What the words are names what the browser fills them in with; words of no such kind, unpredicted, take none.
        let filled: String? = switch traits.content {
        case .emailAddress: "email"
        case .telephoneNumber: "tel"
        case .url: "url"
        case .username: "username"
        case .newPassword: "new-password"
        case .oneTimeCode: "one-time-code"
        case nil: traits.predicts ? nil : "off"
        }
        attribute("autocomplete", filled)
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
        attribute("data-grows", grows ? "" : nil)
        attribute("rows", grows ? "1" : nil)
        style("overflow", grows ? "hidden" : nil)
        style("resize", grows ? "none" : nil)
        fit()
    }

    /// A field counts its words or its placeholder as wide as it is; an editor growing with its words stands as tall
    /// as they are.
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
