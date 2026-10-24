// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A link: the page's own `<a href>`, its words in their color - the browser's link color where the tree gives none
/// - its address there only where the page may open one (`WebFileToolkit.launches`), and a click the host layer
/// opens it on as a launched address opens, in place of the browser's own following of it.
/// Design: docs/design/platforms/web/controls.md#a-link
@MainActor
final class WebLinkView: WebDOMView {
    /// What a click does: the host layer opens the link's address.
    var onClicked: (() -> Void)?

    init() {
        super.init(tag: "a")
        attribute("class", "stateui-link")
        // A hand moving over the link is the tree's, not the browser's drag of its address.
        attribute("draggable", "false")
        listen("click") { [weak self] in
            WebRelay.takeEvent()
            self?.onClicked?()
        }
    }

    /// The address it stands for, where the page may open it; none leaves it no address, and no stop of Tab's.
    func setDestination(_ address: String?) {
        attribute("href", address.flatMap { WebFileToolkit.launches($0) ? $0 : nil })
    }

    /// Its words.
    func setText(_ text: String) {
        WebRelay.setText(node, text)
    }

    /// Its words' color; nil for the browser's link color.
    func setColor(_ color: HostValue?) {
        style("color", WebCSS.color(color))
    }

    /// A link with an address is a link of itself.
    override var role: String? { nil }

    override var isControl: Bool { true }
}
