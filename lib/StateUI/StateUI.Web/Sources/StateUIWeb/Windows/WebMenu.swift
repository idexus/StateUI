// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A menu as the page shows one: the host layer's walk of its entries (`MenuEntry`) as a popover over everything -
/// an item a button, a separator a line, a submenu a button opening its own popover beside it - which a click beside
/// it or Escape takes down, as does choosing an item, which then hears it chosen.
/// Design: docs/design/platforms/web/pages.md#menus
@MainActor
final class WebMenu {
    private let popover = WebDOMView(tag: "div")

    /// How many entries stand in the menu, and every element it made, which it lets go of as it goes.
    private var placed = 0
    private var owned: [WebDOMView] = []
    private var submenus: [WebMenu] = []

    /// The menu this one stands in, which choosing an item takes down whole.
    private weak var parent: WebMenu?

    /// The menus open now, each held until it goes; a menu inside one is held by it.
    private static var open: [ObjectIdentifier: WebMenu] = [:]

    /// A menu of `entries`; one of none shows nothing.
    init(_ entries: [MenuEntry], in parent: WebMenu? = nil) {
        self.parent = parent
        popover.attribute("class", "stateui-menu")
        popover.attribute("popover", "auto")
        popover.attribute("role", "menu")
        popover.attribute("tabindex", "-1")
        for entry in entries { add(entry) }
        popover.listen("closed") { [weak self] in self?.closed() }
    }

    var isEmpty: Bool { placed == 0 }

    /// Shows the menu under `anchor`'s view, or at `point` in the window.
    func show(under anchor: WebDOMView? = nil, at point: Point = Point(x: 0, y: 0)) {
        guard !isEmpty else { return }
        Self.open[ObjectIdentifier(self)] = self
        WebRelay.insert(popover.node, into: WebRelay.body, at: 0)
        WebRelay.showPopover(popover.node, under: anchor?.node ?? 0, at: point)
        // The keyboard comes to the menu, where the arrows go through its items.
        _ = WebRelay.focus(popover.node)
    }

    private func add(_ entry: MenuEntry) {
        switch entry.kind {
        case .separator:
            guard placed > 0 else { return }
            let line = WebDOMView(tag: "div")
            line.attribute("role", "separator")
            place(line)
        case .item:
            let button = item(entry)
            button.listen("click") { [weak self] in
                guard let self, entry.isEnabled else { return }
                takeDown()
                (entry.element?.native as? WebElement)?.send(.clicked, [])
            }
        case .submenu:
            let button = item(entry)
            button.attribute("aria-haspopup", "menu")
            let inner = WebMenu(entry.entries, in: self)
            submenus.append(inner)
            WebRelay.insert(inner.popover.node, into: popover.node, at: Int(Int32.max))
            button.listen("click") { [weak button, weak inner] in
                guard let button, let inner, !inner.isEmpty else { return }
                WebRelay.showPopover(inner.popover.node, under: button.node, beside: true)
            }
        }
    }

    /// A button for an entry: its picture, its caption, whether it can be chosen, whether it destroys something.
    private func item(_ entry: MenuEntry) -> WebDOMView {
        let button = WebDOMView(tag: "button")
        button.attribute("type", "button")
        button.attribute("role", "menuitem")
        button.attribute("data-identifier", entry.identifier)
        button.attribute("data-destructive", entry.isDestructive ? "" : nil)
        button.attribute("disabled", entry.isEnabled ? nil : "")
        if let icon = entry.icon {
            let picture = WebImageView()
            picture.apply(source: ImageSource(icon), aspect: .fit)
            WebRelay.insert(picture.node, into: button.node, at: 0)
            owned.append(picture)
        }
        let words = WebDOMView(tag: "span")
        WebRelay.setText(words.node, entry.title)
        WebRelay.insert(words.node, into: button.node, at: entry.icon == nil ? 0 : 1)
        owned.append(words)
        place(button)
        return button
    }

    private func place(_ part: WebDOMView) {
        WebRelay.insert(part.node, into: popover.node, at: placed)
        placed += 1
        owned.append(part)
    }

    /// Takes down the menu this one stands in, whole.
    private func takeDown() {
        guard let parent else { return WebRelay.hidePopover(popover.node) }
        parent.takeDown()
    }

    /// The menu went: everything in it lets go, and it is held no more.
    private func closed() {
        guard parent == nil else { return }
        release()
        Self.open[ObjectIdentifier(self)] = nil
    }

    private func release() {
        for submenu in submenus { submenu.release() }
        for part in owned { part.detach() }
        popover.detach()
    }
}
