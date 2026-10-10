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

    init() {
        super.init(tag: "button")
        attribute("type", "button")
        WebRelay.insert(picture.node, into: node, at: 0)
        WebRelay.insert(words.node, into: node, at: 1)
        listen("click") { [weak self] in
            guard let self, let item, let element = item.native as? WebElement else { return }
            guard item.type == .menu else { return element.send(.clicked, []) }
            WebMenu(MenuEntry.entries(of: item)).show(under: self)
        }
    }

    func show(_ item: MountedElement) {
        self.item = item
        let text = item.value(.text)?.string ?? ""
        let icon = item.value(.icon)?.string ?? ""
        picture.apply(source: icon.isEmpty ? nil : ImageSource(icon), aspect: .fit)
        picture.setShown(!icon.isEmpty)
        WebRelay.setText(words.node, text)
        words.setShown(item.showsActionWords)
        attribute("aria-label", text)
        attribute("title", text)
        attribute("disabled", item.isEffectivelyEnabled ? nil : "")
        attribute("data-destructive", item.value(.isDestructive)?.bool == true ? "" : nil)
        attribute("data-identifier", item.value(.accessibilityIdentifier)?.string)
        attribute("aria-haspopup", item.type == .menu ? "menu" : nil)
    }

    override func detach() {
        picture.detach()
        words.detach()
        super.detach()
    }
}
