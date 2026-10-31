// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// How a button on the page - a button among views, a bar's - opens its menu: its click; as a split button, its click
/// its own, its arrow - a part set off by a line - opening the menu; or held. A right click or a finger held opens a
/// split button's and a held one's. The button asks it of each click whether the click was the menu's.
/// Design: docs/design/platforms/web/controls.md#a-buttons-menu
@MainActor
final class WebButtonMenu {
    /// How the button opens its menu, its own for good.
    let opening: ButtonMenuOpening

    /// A split button's arrow, the part opening its menu; nil for any other button.
    private var arrow: WebDOMView?

    /// Whether the click under way landed on the arrow, which opened the menu in place of clicking the button.
    private var arrowClicked = false

    /// What opens the menu where a click opens it; nil where the click is the button's own.
    private var opensMenu: (() -> Void)?

    /// Makes `button` open its menu - by `open` - as `opening` says.
    init(on button: WebDOMView, _ opening: ButtonMenuOpening, _ open: @escaping () -> Void) {
        self.opening = opening
        button.attribute("aria-haspopup", "menu")
        button.attribute("data-menu", opening == .click ? "opens" : opening == .arrow ? "splits" : "held")
        if opening == .click {
            opensMenu = open
            return
        }
        guard opening == .arrow else {
            button.listenForMenu { open() }
            return
        }

        let arrow = WebDOMView(tag: "span")
        arrow.attribute("class", "stateui-split-arrow")
        arrow.attribute("aria-hidden", "true")
        // Last, after the words and a picture put before them.
        WebRelay.insert(arrow.node, into: button.node, at: .max)
        arrow.listen("click") { [weak self] in
            self?.arrowClicked = true
            open()
        }
        self.arrow = arrow
        button.listenForMenu { open() }
    }

    /// Takes a click on the button: true where it was the menu's - its arrow's, or a click opening the menu.
    func takes() -> Bool {
        if arrowClicked {
            arrowClicked = false
            return true
        }
        guard let opensMenu else { return false }
        opensMenu()
        return true
    }

    func release() {
        opensMenu = nil
        arrow?.release()
        arrow = nil
    }
}
