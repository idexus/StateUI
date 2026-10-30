// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIUIKit
@_spi(Host) import StateUIConformance

/// What the UIKit driver reads of the screen: the color at a point of a view, and whether a touch there reaches it.
/// Design: docs/design/platforms/uikit/conformance.md#what-the-driver-reads
extension UIKitDriver {
    /// The color the user sees at `point` of the element's view, as the screen shows it, in sRGB; nil where
    /// nothing opaque is drawn there.
    func color(of element: MountedElement, at point: Point) throws -> Color? {
        guard let view = (element.native as? UIKitElement)?.view else {
            throw DriverCannot("read the color of \(element.type.name)")
        }
        renderer?.layOut()
        let size = view.bounds.size
        let (width, height) = (Int(size.width.rounded(.up)), Int(size.height.rounded(.up)))
        guard point.x >= 0, point.y >= 0, point.x < size.width, point.y < size.height, width > 0, height > 0,
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.preferredRange = .standard
        let drawn = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        }
        guard let image = drawn.cgImage, let data = context.data else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        // A bitmap context's rows stand in memory from its top.
        let pixel = data.advanced(by: min(height - 1, Int(point.y)) * width * 4 + min(width - 1, Int(point.x)) * 4)
            .assumingMemoryBound(to: UInt8.self)
        let alpha = Int(pixel[3])
        guard alpha > 127 else { return nil }
        func channel(_ index: Int) -> Int { min(255, Int(pixel[index]) * 255 / alpha) }
        return Color(red: channel(0), green: channel(1), blue: channel(2))
    }

    /// The bar at `edge` of `page`: at its top read from its navigation item - its leading and trailing groups, the
    /// overflow's entries - at its foot from its toolbar items.
    func bar(of page: MountedElement, at edge: ToolbarEdge) throws -> String {
        guard edge == .top else { return try toolbar(of: page) }
        guard let item = (page.native as? UIKitElement)?.controller?.navigationItem else {
            throw DriverCannot("read the bar of \(page.type.name)")
        }
        let word = Self.word(on: page)
        let groups = { (groups: [UIBarButtonItemGroup]) -> [[String]] in
            groups.map { $0.barButtonItems.compactMap(word) }.filter { !$0.isEmpty }
        }
        let overflow = item.trailingItemGroups.flatMap(\.barButtonItems)
            .filter { $0.primaryAction == nil && $0.customView == nil }
            .flatMap { Self.entries(of: $0, on: page) }
        return BarWords.said(
            leading: groups(item.leadingItemGroups), trailing: groups(item.trailingItemGroups), overflow: overflow)
    }

    /// How the bar over `page` says an item of its own - an action by the element whose identifier it carries, words
    /// by the element whose label it shows; nil for one no element stands for.
    private static func word(on page: MountedElement) -> (UIBarButtonItem) -> String? {
        var root = page
        while let parent = root.parent { root = parent }
        let elements = toolbarItems(in: root)
        return { item in
            let element = elements.first { element in
                guard let native = element.native as? UIKitElement else { return false }
                if let label = item.customView { return native.barLabel === label }
                return item.primaryAction.map { $0.identifier == native.actionIdentifier } ?? false
            }
            return element.map { BarWords.word($0, enabled: item.isEnabled) }
        }
    }

    /// The entries of the menu `item` opens behind a bar's overflow, each said by its element.
    private static func entries(of item: UIBarButtonItem, on page: MountedElement) -> [String] {
        var root = page
        while let parent = root.parent { root = parent }
        let elements = toolbarItems(in: root)
        return (item.menu?.children ?? []).compactMap { entry in
            guard let action = entry as? UIAction,
                  let element = elements.first(where: { ($0.native as? UIKitElement)?.actionIdentifier == action.identifier })
            else { return nil }
            return BarWords.word(element, enabled: !action.attributes.contains(.disabled))
        }
    }

    /// The bar at `page`'s foot, read from its toolbar items while its stack shows the toolbar: the groups apart by
    /// fixed spaces, the leading before the space between the edges, the overflow the More button's entries.
    private func toolbar(of page: MountedElement) throws -> String {
        guard let controller = (page.native as? UIKitElement)?.controller else {
            throw DriverCannot("read the bar at the foot of \(page.type.name)")
        }
        guard controller.navigationController?.isToolbarHidden == false else {
            return BarWords.said(leading: [], trailing: [], overflow: [])
        }
        let word = Self.word(on: page)
        var sides: [[[String]]] = [[[]]]
        var overflow: [String] = []
        for item in controller.toolbarItems ?? [] {
            if item.identifier == UIKitPageToolbar.betweenIdentifier {
                sides.append([[]])
            } else if item.identifier == UIKitPageToolbar.moreIdentifier {
                overflow = Self.entries(of: item, on: page)
            } else if let said = word(item) {
                sides[sides.count - 1][sides[sides.count - 1].count - 1].append(said)
            } else {
                sides[sides.count - 1].append([])
            }
        }
        let groups = { (side: Int) in sides.indices.contains(side) ? sides[side].filter { !$0.isEmpty } : [] }
        return BarWords.said(leading: groups(0), trailing: groups(1), overflow: overflow)
    }

    /// Every toolbar item under `root`, the arrangements' slots included.
    private static func toolbarItems(in root: MountedElement) -> [MountedElement] {
        (NodeType.toolbarItemTypes.contains(root.type) ? [root] : []) + (root.children + root.slots).flatMap { toolbarItems(in: $0) }
    }

    /// A view's context menu, or a window's menus on the menu bar, as UIKit is handed them.
    func menu(of element: MountedElement) throws -> String {
        if element.type == .window { return UIKitMenus.said(renderer?.menuBar ?? []) }
        guard let native = element.native as? UIKitElement, native.view != nil else {
            throw DriverCannot("read the menu of \(element.type.name)")
        }
        return UIKitMenus.said(native.builtContextMenu?.children ?? [])
    }

    /// The menu UIKit's button standing for `button` holds - a bar's button, the menu of its bar button.
    func buttonMenu(of button: MountedElement) throws -> String {
        if button.type == .toolbarButton {
            guard let identifier = (button.native as? UIKitElement)?.menuIdentifier,
                  let menu = barMenu(identified: identifier)
            else { throw DriverCannot("read the menu \(button.type.name) opens: its bar button opens none") }
            return UIKitMenus.said(menu.children)
        }
        guard let view = (button.native as? UIKitElement)?.view as? UIKitButtonView, let menu = view.offeredMenu else {
            throw DriverCannot("read the menu \(button.type.name) opens")
        }
        return UIKitMenus.said(menu.children)
    }

    /// The question UIKit's alert shows now, as it shows it.
    func question(over element: MountedElement) throws -> Question? {
        guard let shown = renderer?.actToolkit.showing else { return nil }
        let field = shown.question.kind == .prompt ? shown.alert.textFields?.first?.text ?? "" : nil
        return Question(
            title: shown.alert.title ?? "", message: shown.alert.message ?? "", buttons: shown.buttons.map(\.caption),
            field: field)
    }

    /// The file dialog UIKit's document picker shows now: one that opens or one that exports.
    /// What the activity sheet the window presents offers: its words, then its link on a line of its own.
    func shared(over element: MountedElement) throws -> String? {
        guard let sheet = renderer?.actToolkit.sharing, sheet.controller != nil else { return nil }
        return sheet.shared.together
    }

    func fileDialog(over element: MountedElement) throws -> FileDialog? {
        guard let shown = renderer?.fileToolkit.showing, shown.picker != nil else { return nil }
        return shown.dialog.kind == .save ? .save : .open
    }

    /// What the host handed iOS to launch, in order: an address as written, a file by its name.
    func launched() throws -> [String] {
        (renderer?.fileToolkit.launchedForTesting ?? []).map { target in
            target.contains("://") ? target : URL(fileURLWithPath: target).lastPathComponent
        }
    }

    /// What the host told VoiceOver, in order.
    func announced() throws -> [String] {
        renderer?.actToolkit.announcedForTesting ?? []
    }

    /// The style the user's window stands in.
    func theme() throws -> ColorScheme {
        guard let window = renderer?.userWindow else { throw DriverCannot("read the theme: no window shows") }
        return window.traitCollection.userInterfaceStyle == .dark ? .dark : .light
    }

    /// The tint the user's window draws its controls in.
    func accent() throws -> Color {
        guard let window = renderer?.userWindow else { throw DriverCannot("read the accent: no window shows") }
        // A window with no tint of its own draws in the system's.
        let tint: UIColor? = window.tintColor
        return Self.color(tint ?? UIColor.tintColor.resolvedColor(with: window.traitCollection))
    }

    /// The words the host keeps under `key` for the next launch.
    func kept(_ key: String, inScene: Bool) throws -> String? {
        if inScene {
            let record = TestScene.scene?.session.userInfo?[UIKitRenderer.recordKey] as? String
            return record.flatMap(WindowRecord.init)?.kept[key]?.string
        }
        return TestScene.preferences.string(forKey: key)
    }

    /// Whether a touch at `point` of the element's view lands on it or on something inside it, as the window's
    /// hit testing finds it.
    func reaches(_ element: MountedElement, at point: Point) throws -> Bool {
        guard let view = (element.native as? UIKitElement)?.view, let window = view.window else {
            throw DriverCannot("read what reaches \(element.type.name)")
        }
        renderer?.layOut()
        let touched = view.convert(CGPoint(x: point.x, y: point.y), to: window)
        guard let hit = window.hitTest(touched, with: nil) else { return false }
        return hit === view || hit.isDescendant(of: view)
    }

    /// A heading is a view VoiceOver meets with the header trait.
    func isHeading(_ element: MountedElement) throws -> Bool {
        guard let view = (element.native as? UIKitElement)?.view else {
            throw DriverCannot("read whether \(element.type.name) is a heading")
        }
        return Self.met(view).accessibilityTraits.contains(.header)
    }

    /// The layout's children by where each one's view stands among its view's subviews - a higher layer's
    /// `zPosition` drawn later still - the last drawn last.
    func drawingOrder(of layout: MountedElement) throws -> [MountedElement] {
        let cannot = DriverCannot("read the drawing order of \(layout.type.name)")
        guard let parent = (layout.native as? UIKitElement)?.view else { throw cannot }
        return try layout.children.map { child in
            guard var view = (child.native as? UIKitElement)?.view else { throw cannot }
            while let above = view.superview, above !== parent { view = above }
            guard let place = parent.subviews.firstIndex(where: { $0 === view }) else { throw cannot }
            return (child, view.layer.zPosition, place)
        }
        .sorted { ($0.1, $0.2) < ($1.1, $1.2) }.map(\.0)
    }
}
