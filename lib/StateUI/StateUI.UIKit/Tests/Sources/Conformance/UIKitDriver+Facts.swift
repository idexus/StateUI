// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIUIKit
@_spi(Host) import StateUIConformance

/// What the UIKit driver reads of the screen: the colour at a point of a view, and whether a touch there reaches it.
/// Design: docs/design/platforms/uikit/conformance.md#what-the-driver-reads
extension UIKitDriver {
    /// The colour the user sees at `point` of the element's view, as the screen shows it, in sRGB; nil where
    /// nothing opaque is drawn there.
    func color(of element: MountedElement, at point: Point) throws -> Color? {
        guard let view = (element.native as? UIKitElement)?.view else {
            throw DriverCannot("read the colour of \(element.type.name)")
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

    /// The bar `page` shows, read from its navigation item: its leading and trailing groups, the overflow's entries -
    /// each action told by the element whose identifier it carries.
    func bar(of page: MountedElement) throws -> String {
        guard let item = (page.native as? UIKitElement)?.controller?.navigationItem else {
            throw DriverCannot("read the bar of \(page.type.name)")
        }
        var root = page
        while let parent = root.parent { root = parent }
        let items = Self.toolbarItems(in: root)
        let word = { (action: UIAction?, enabled: Bool) -> String? in
            guard let action, let element = items.first(where: { ($0.native as? UIKitElement)?.actionIdentifier == action.identifier })
            else { return nil }
            return BarWords.word(element, enabled: enabled)
        }
        let groups = { (groups: [UIBarButtonItemGroup]) -> [[String]] in
            groups.map { $0.barButtonItems.compactMap { word($0.primaryAction, $0.isEnabled) } }.filter { !$0.isEmpty }
        }
        let overflow = item.trailingItemGroups.flatMap(\.barButtonItems).filter { $0.primaryAction == nil }
            .flatMap { $0.menu?.children ?? [] }
            .compactMap { ($0 as? UIAction).flatMap { word($0, !$0.attributes.contains(.disabled)) } }
        return BarWords.said(
            leading: groups(item.leadingItemGroups), trailing: groups(item.trailingItemGroups), overflow: overflow)
    }

    /// Every toolbar item under `root`, the arrangements' slots included.
    private static func toolbarItems(in root: MountedElement) -> [MountedElement] {
        (root.type == .toolbarItem ? [root] : []) + (root.children + root.slots).flatMap { toolbarItems(in: $0) }
    }

    /// A view's context menu, or a window's menus on the menu bar, as UIKit is handed them.
    func menu(of element: MountedElement) throws -> String {
        if element.type == .window { return UIKitMenus.said(renderer?.menuBar ?? []) }
        guard let native = element.native as? UIKitElement, native.view != nil else {
            throw DriverCannot("read the menu of \(element.type.name)")
        }
        return UIKitMenus.said(native.builtContextMenu?.children ?? [])
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

    /// What the host keeps under `key` for the next launch, as it reads it back.
    func kept(_ key: String, inScene: Bool) throws -> HostValue? {
        if inScene {
            let record = TestScene.scene?.session.userInfo?[UIKitRenderer.recordKey] as? String
            return record.flatMap(WindowRecord.init)?.kept[key]
        }
        guard let word = TestScene.preferences.string(forKey: key) else { return nil }
        let kinds = [
            PersistentKey(key, of: String.self), PersistentKey(key, of: Double.self), PersistentKey(key, of: Bool.self),
        ]
        return kinds.lazy.compactMap { KeptWord.restored([key: word], for: [$0])[key] }.first
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
        return view.accessibilityTraits.contains(.header)
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
