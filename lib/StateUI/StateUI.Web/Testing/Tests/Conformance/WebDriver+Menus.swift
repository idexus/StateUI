// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@_spi(Host) import StateUIConformance
@testable import StateUIWeb

/// The menus the page shows, as the user meets them: a view's opened by the mouse's other button, the window's
/// behind the bar's More, read as they stand open and each taken down after with Escape - and an item chosen with
/// a click, its submenus opened on the way.
/// Design: docs/design/host/conformance.md#the-driver
extension WebDriver {
    /// The menu open now, as `menu(of:)` says it.
    private static let saidOpen = """
        (function said(menu) {
          if (!menu) return '';
          const inner = [...menu.children].filter((c) => c.classList.contains('stateui-menu'));
          let k = 0;
          return [...menu.children].filter((c) => !c.classList.contains('stateui-menu')).map((c) => {
            if (c.getAttribute('role') === 'separator') return '-';
            const caption = (c.disabled ? '!' : '') + ([...c.querySelectorAll('span')].pop()?.textContent ?? '');
            return c.getAttribute('aria-haspopup') === 'menu' ? caption + '[' + said(inner[k++]) + ']' : caption;
          }).join(';');
        })([...document.querySelectorAll('.stateui-menu')].find((m) => m.matches(':popover-open') && !m.parentElement.closest('.stateui-menu')))
        """

    func menu(of element: MountedElement) throws -> String {
        try open(menuOf: element)
        defer { press("Escape") }
        return try WebBrowser.evaluate(Self.saidOpen, on: 0) ?? ""
    }

    /// The item `element` chosen from its menu, as the user does: the menu opened, each submenu on its way, the
    /// item clicked.
    func choose(_ element: MountedElement) throws {
        let path = captions(to: element)
        guard let anchor = menuAnchor(of: element), !path.isEmpty else { throw DriverCannot(.activate, on: element) }
        try open(menuOf: anchor)
        for (depth, caption) in path.enumerated() {
            let item = try openItem(caption, depth: depth)
            try click(item)
        }
    }

    /// What an item of a menu holds, read from its button as the open menu shows it.
    func menuItemHolds(_ property: Prop, on element: MountedElement) throws -> HostValue?? {
        let path = captions(to: element)
        guard let anchor = menuAnchor(of: element), !path.isEmpty else { return nil }
        try open(menuOf: anchor)
        defer { press("Escape") }
        for (depth, caption) in path.dropLast().enumerated() { try click(try openItem(caption, depth: depth)) }
        let item = try openItem(path.last!, depth: path.count - 1)
        switch property {
        case .text: return try WebBrowser.evaluate("[...e.querySelectorAll('span')].pop()?.textContent ?? null", on: item)?.propValue
        case .isEnabled: return try (!WebBrowser.truth("e.disabled", on: item)).propValue
        case .isDestructive: return try WebBrowser.truth("e.hasAttribute('data-destructive')", on: item).propValue
        case .accessibilityIdentifier: return .some(try WebBrowser.evaluate("e.dataset.identifier ?? null", on: item)?.propValue)
        case .icon: return .some(try picture("e.querySelector('img')", on: item))
        default: return nil
        }
    }

    /// Opens the menu `element` offers: the window's behind the bar's More, a view's with the mouse's other button.
    private func open(menuOf element: MountedElement) throws {
        if element.type == .window {
            return try click(try bar(over: element), part: "button[aria-label=More]")
        }
        let view = try self.view(of: element, reading: .frame)
        let box = try box(of: view.node)
        let middle = Point(x: box.width / 2, y: box.height / 2)
        mouse("mousePressed", at: middle, in: box, button: "right")
        mouse("mouseReleased", at: middle, in: box, button: "right")
    }

    /// The button of the item `caption` in the menu open at `depth` - the outermost 0.
    private func openItem(_ caption: String, depth: Int) throws -> Int32 {
        let menus = "[...document.querySelectorAll('.stateui-menu')].filter((m) => m.matches(':popover-open'))"
        let script = "((m) => m && [...m.children].find((c) => [...c.querySelectorAll('span')].pop()?.textContent === "
            + "\(WebBrowser.quoted(caption))))(\(menus)[\(depth)])"
        guard let node = try WebBrowser.number("((b) => b ? stateui.numberOf(b) : null)(\(script))", on: 0) else {
            throw DriverCannot("find \(caption) in a menu")
        }
        return Int32(node)
    }

    /// The captions from the menu an item stands in down to the item: each submenu's, then its own.
    private func captions(to element: MountedElement) -> [String] {
        var path: [String] = []
        var current: MountedElement? = element
        while let each = current, each.type == .menuItem || each.type == .menu {
            path.insert(each.value(.text)?.string ?? "", at: 0)
            current = each.parent
        }
        return path
    }

    /// What offers the menu an item stands in: the view a context menu is of, or the window of a menu bar.
    private func menuAnchor(of element: MountedElement) -> MountedElement? {
        var current = element.parent
        while let each = current {
            if each.type == .contextMenu { return each.parent }
            if each.type == .menuBar { return windowOf(each) }
            current = each.parent
        }
        return nil
    }

    private func windowOf(_ element: MountedElement) -> MountedElement? {
        var current: MountedElement? = element
        while let each = current, each.type != .window { current = each.parent }
        return current
    }
}
