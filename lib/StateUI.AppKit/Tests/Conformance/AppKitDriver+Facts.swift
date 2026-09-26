// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIAppKit
@_spi(Host) import StateUIConformance

/// What the AppKit driver reads besides a member's value: a view's menu and the page's menus, the keyboard's
/// holder, and what a press reaches - each from AppKit itself.
/// Design: docs/design/platforms/appkit/conformance.md#what-the-driver-reads
extension AppKitDriver {
    func menu(of element: MountedElement) throws -> String {
        if element.type == .window { return Self.said(try controller(of: element).pageMenuItemsForTesting) }
        guard let view = (element.native as? AppKitElement)?.view else {
            throw DriverCannot("read the menu of \(element.type.name)")
        }
        return Self.said(view.menu?.items ?? [])
    }

    func focused(_ element: MountedElement) throws -> Bool {
        guard let view = (element.native as? AppKitElement)?.view else {
            throw DriverCannot("read the focus of \(element.type.name)")
        }
        return AppKitFocus.holds(view, view.window?.firstResponder)
    }

    func reaches(_ element: MountedElement, at point: Point) throws -> Bool {
        guard let view = (element.native as? AppKitElement)?.view, let window = view.window,
              let content = window.contentView, let frame = content.superview
        else { throw DriverCannot("read what reaches \(element.type.name)") }
        content.layoutSubtreeIfNeeded()
        let local = NSPoint(x: point.x, y: view.isFlipped ? point.y : view.bounds.height - point.y)
        guard let hit = content.hitTest(frame.convert(view.convert(local, to: nil), from: nil)) else { return false }
        return hit === view || hit.isDescendant(of: view)
    }

    /// Menu items as the suite writes them: each by its caption, "!" before one that cannot be chosen, "-" a
    /// separator, a submenu's entries in brackets after its caption, ";" between.
    static func said(_ items: [NSMenuItem]) -> String {
        items.map { item in
            if item.isSeparatorItem { return "-" }
            let caption = (item.isEnabled ? "" : "!") + item.title
            guard let submenu = item.submenu else { return caption }
            return caption + "[" + said(submenu.items) + "]"
        }.joined(separator: ";")
    }
}
#endif
