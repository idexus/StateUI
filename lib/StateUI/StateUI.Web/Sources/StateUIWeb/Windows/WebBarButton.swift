// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// One action of the bar: its picture, its words beside it where it shows them, whether it can be chosen - a menu's
/// opening its entries under it.
@MainActor
final class WebBarButton: WebDOMView {
    private let picture = WebImageView()
    private let words = WebDOMView(tag: "span")

    /// The item the button stands for, which hears it chosen.
    private(set) weak var item: MountedElement?

    /// How the button opens the menu its item holds; nil for an item holding none.
    private var menu: WebButtonMenu?

    /// How the button opens its item's menu, its own for good: an item opening it otherwise is another button.
    let opening: ButtonMenuOpening

    /// A button for an item opening a menu as `opening` says.
    init(opening: ButtonMenuOpening = .none) {
        self.opening = opening
        super.init(tag: "button")
        attribute("type", "button")
        WebRelay.insert(picture.node, into: node, at: 0)
        WebRelay.insert(words.node, into: node, at: 1)
        if opening != .none {
            menu = WebButtonMenu(on: self, opening) { [weak self] in
                guard let self, let item else { return }
                WebMenu(ButtonMenu.entries(of: item)).show(under: self)
            }
        }
        listen("click") { [weak self] in
            guard let self, menu?.takes() != true, let item, let element = item.native as? WebElement else { return }
            guard item.type == .menu else { return element.choose() }
            WebMenu(MenuEntry.entries(of: item)).show(under: self)
        }
        // The pointer over the button and a press on it, which its item's states follow.
        for (said, event) in [("pointerenter", Event.pointerEntered), ("pointerleave", .pointerExited),
                              ("pointerdown", .pressed), ("pointerup", .released), ("pointercancel", .released)] {
            listen(said) { [weak self] in (self?.item?.native as? WebElement)?.hearOnBar(event) }
        }
    }

    func show(_ item: MountedElement) {
        self.item = item
        // Read as a menu's entry is (`MenuEntry`).
        let entry = MenuEntry.entry(of: item)
        picture.apply(picture: entry.icon, aspect: .fit)
        picture.setShown(entry.icon != nil)
        WebRelay.setText(words.node, entry.title)
        words.setShown(item.showsActionWords)
        attribute("aria-label", entry.title)
        attribute("title", entry.title)
        attribute("disabled", entry.isEnabled ? nil : "")
        attribute("data-destructive", entry.isDestructive ? "" : nil)
        attribute("data-identifier", entry.identifier)
        if opening == .none { attribute("aria-haspopup", item.type == .menu ? "menu" : nil) }
        // A button whose click opens its menu says so by its arrow, unless the tree says it shows none.
        attribute("data-bare", opening == .click && !ButtonMenu.showsArrow(item) ? "" : nil)
        // A setting is a two-state button: pressed while on.
        attribute("aria-pressed", item.type == .toolbarToggle ? (entry.isOn == true ? "true" : "false") : nil)
        attribute("aria-keyshortcuts", entry.keyboardShortcut.map { WebKeys.spelled($0, onApple: WebRelay.onApple) })
        showBarLook { item.value($0) }
    }

    override func release() {
        menu?.release()
        picture.release()
        words.release()
        super.release()
    }
}
