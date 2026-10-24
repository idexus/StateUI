// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A Button: the browser's `<button>` holding its words and its picture beside them, its look the browser's own until
/// the application gives its box a fill, an outline or a shape.
/// Design: docs/design/platforms/web/controls.md#a-button
@MainActor
final class WebButtonView: WebDOMView, WebWordsView {
    var onClicked: () -> Void = {}

    private let words = WebDOMView(tag: "span")
    private var picture: WebImageView?
    private var text = ""

    /// How the button opens its menu; nil for a button holding none.
    private var menu: WebButtonMenu?

    init() {
        super.init(tag: "button")
        attribute("type", "button")
        attribute("class", "stateui-button")
        WebRelay.insert(words.node, into: node, at: 0)
        listen("click") { [weak self] in
            guard let self, menu?.takes() != true else { return }
            onClicked()
        }
    }

    /// Makes the button open its menu - by `open` - as `opening` says (`WebButtonMenu`).
    func holdMenu(_ opening: ButtonMenuOpening, _ open: @escaping () -> Void) {
        menu = WebButtonMenu(on: self, opening, open)
    }

    /// Whether a button whose click opens its menu shows the `▾` saying so.
    func showsMenuArrow(_ shows: Bool) {
        attribute("data-bare", shows ? nil : "")
    }

    func setText(_ text: String) {
        self.text = text
        WebRelay.setText(words.node, text)
        attribute("data-alone", text.isEmpty && picture != nil ? "" : nil)
    }

    /// How the words break across lines and where they stop; nil for one line, the browser's own.
    func setLines(_ lineBreak: LineBreak?) {
        let breaking = lineBreak ?? .noWrap
        for (name, value) in WebCSS.lines(breaking, most: breaking.lines(maximum: nil)) { words.style(name, value) }
    }

    /// The picture beside the words - before them, after, above or below, `spacing` apart, 8 where nil - or alone,
    /// filling the button as `aspect` says; none shows the words alone.
    func setIcon(_ source: ImageSource?, position: IconPosition, spacing: Double?, aspect: ContentMode) {
        guard let source = HostPicture(source, dark: false) else {
            picture?.release()
            picture = nil
            attribute("data-alone", nil)
            return
        }
        let shown = picture ?? WebImageView()
        if picture == nil { WebRelay.insert(shown.node, into: node, at: 0) }
        picture = shown
        shown.apply(picture: source, aspect: aspect)
        let direction: String? = switch position {
        case .start: nil
        case .end: "row-reverse"
        case .top: "column"
        case .bottom: "column-reverse"
        }
        style("flex-direction", direction)
        style("gap", WebCSS.pixels(spacing ?? 8))
        attribute("data-alone", text.isEmpty ? "" : nil)
    }

    /// A button is a button of itself.
    override var role: String? { nil }

    override var isControl: Bool { true }

    override func release() {
        menu?.release()
        picture?.release()
        words.release()
        super.release()
    }

    override func setEnabled(_ enabled: Bool) {
        attribute("disabled", enabled ? nil : "")
    }

    /// The box the application draws in place of the browser's: its fill, its outline and its shape; with none of
    /// them, the browser's own button.
    func setBox(fill: HostValue?, stroke: HostValue?, lineWidth: Double?, shape: HostValue?) {
        let box = WebBox(fill: fill, stroke: stroke, lineWidth: lineWidth, shape: shape, borderless: "none")
        setBox(box)
        if box.isDrawn, fill == nil { style("background", "transparent") }
    }
}
