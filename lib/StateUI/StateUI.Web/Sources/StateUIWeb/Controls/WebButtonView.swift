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

    /// A split button's arrow, the part opening its menu; nil for any other button.
    private var arrow: WebDOMView?

    /// Whether the click under way landed on the arrow, which opened the menu in place of clicking the button.
    private var arrowClicked = false

    init() {
        super.init(tag: "button")
        attribute("type", "button")
        attribute("class", "stateui-button")
        WebRelay.insert(words.node, into: node, at: 0)
        listen("click") { [weak self] in
            guard let self else { return }
            if arrowClicked {
                arrowClicked = false
                return
            }
            if let opensMenu { opensMenu() } else { onClicked() }
        }
    }

    /// What opens the button's menu where a click opens it; nil where the click is the button's own.
    private var opensMenu: (() -> Void)?

    /// Makes the button open its menu - by `open` - as `opening` says: its click; as a split button, its click its
    /// own, its arrow - a part set off by a line - opening the menu; or held. A right click or a finger held opens a
    /// split button's and a held one's.
    /// Design: docs/design/platforms/web/controls.md#a-buttons-menu
    func holdMenu(_ opening: ButtonMenuOpening, _ open: @escaping () -> Void) {
        attribute("aria-haspopup", "menu")
        attribute("data-menu", opening == .click ? "opens" : opening == .arrow ? "splits" : "held")
        if opening == .click {
            opensMenu = open
            return
        }
        guard opening == .arrow else {
            listenForMenu { open() }
            return
        }

        let arrow = WebDOMView(tag: "span")
        arrow.attribute("class", "stateui-split-arrow")
        arrow.attribute("aria-hidden", "true")
        // Last, after the words and a picture put before them.
        WebRelay.insert(arrow.node, into: node, at: .max)
        arrow.listen("click") { [weak self] in
            self?.arrowClicked = true
            open()
        }
        self.arrow = arrow
        listenForMenu { open() }
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
            picture?.detach()
            picture = nil
            attribute("data-alone", nil)
            return
        }
        let shown = picture ?? WebImageView()
        if picture == nil { WebRelay.insert(shown.node, into: node, at: 0) }
        picture = shown
        shown.apply(picture: source, aspect: aspect)
        let direction: String? = switch position {
        case .leading: nil
        case .trailing: "row-reverse"
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

    override func detach() {
        opensMenu = nil
        picture?.detach()
        arrow?.detach()
        arrow = nil
        words.detach()
        super.detach()
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
