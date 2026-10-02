// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIAppKit
@_spi(Host) import StateUIConformance

/// What the AppKit driver reads besides a control's value: a window's, a view's menu and the page's menus, the
/// keyboard's holder, and what a press reaches - each from AppKit itself.
/// Design: docs/design/platforms/appkit/conformance.md#what-the-driver-reads
extension AppKitDriver {
    func menu(of element: MountedElement) throws -> String {
        if element.type == .window { return Self.said(try controller(of: element).pageMenuItemsForTesting) }
        guard let view = (element.native as? AppKitElement)?.view else {
            throw DriverCannot("read the menu of \(element.type.name)")
        }
        return Self.said(view.menu?.items ?? [])
    }

    /// The bar the window of `page` shows, read from its toolbar: the actions before the first flexible space and
    /// after the last, each run between two spaces a group, then the overflow's actions.
    func bar(of page: MountedElement) throws -> String {
        let toolbar = try controller(of: page).toolbarForTesting
        let identifiers = toolbar.identifiersForTesting
        var root = page
        while let parent = root.parent { root = parent }
        let word = { (identifier: NSToolbarItem.Identifier, enabled: Bool) -> String? in
            guard identifier.rawValue.hasPrefix("StateUI.action."),
                  let mount = UInt64(identifier.rawValue.dropFirst("StateUI.action.".count)),
                  let element = Self.element(mounted: mount, in: root)
            else { return nil }
            return BarWords.word(element, enabled: enabled)
        }
        let groups = { (part: ArraySlice<NSToolbarItem.Identifier>) -> [[String]] in
            part.split(separator: .space).map { run in
                run.compactMap { word($0, toolbar.itemForTesting($0)?.isEnabled ?? true) }
            }.filter { !$0.isEmpty }
        }
        let first = identifiers.firstIndex(of: .flexibleSpace) ?? identifiers.endIndex
        let last = identifiers.lastIndex(of: .flexibleSpace).map { $0 + 1 } ?? identifiers.endIndex
        return BarWords.said(
            leading: groups(identifiers[..<first]), trailing: groups(identifiers[last...]),
            overflow: toolbar.overflowForTesting.compactMap { word($0.identifier, $0.isEnabled) })
    }

    /// The element of `mount` in the tree under `root`, its slots included.
    private static func element(mounted mount: UInt64, in root: MountedElement) -> MountedElement? {
        if root.mount == mount { return root }
        for child in root.children + root.slots {
            if let found = element(mounted: mount, in: child) { return found }
        }
        return nil
    }

    /// A window's: its title, the place and size of its content area, their bounds, its buttons, the desktop through
    /// it, whether it floats, and the kind and value its restoration record keeps. The driver orders no window in, so
    /// none stands shown or hidden to read.
    func windowHolds(_ property: Prop, _ element: MountedElement) throws -> HostValue? {
        let controller = try controller(of: element)
        guard let window = controller.window else { throw DriverCannot(reading: property, of: element) }
        let chrome = window.frame.height - window.contentLayoutRect.height
        let screen = window.screen ?? NSScreen.main
        switch property {
        case .title: return window.title.propValue
        case .x: return Double(window.frame.minX).rounded().propValue
        case .y: return screen.map { Double($0.visibleFrame.maxY - window.frame.maxY).rounded().propValue }
        case .width: return Double(window.contentLayoutRect.width).rounded().propValue
        case .height: return Double(window.contentLayoutRect.height).rounded().propValue
        case .minimumWidth: return Double(window.contentMinSize.width).propValue
        case .minimumHeight: return Double(window.contentMinSize.height - chrome).rounded().propValue
        case .maximumWidth: return Double(window.contentMaxSize.width).propValue
        case .maximumHeight: return Double(window.contentMaxSize.height - chrome).rounded().propValue
        case .isMaximizable: return (window.standardWindowButton(.zoomButton)?.isEnabled ?? false).propValue
        case .isMinimizable: return window.styleMask.contains(.miniaturizable).propValue
        case .isTranslucent: return (!window.isOpaque).propValue
        case .floatsOnTop: return (window.level == .floating).propValue
        case .windowType: return controller.restorationRecordForTesting.kind.map { .name($0) }
        case .windowValue: return controller.restorationRecordForTesting.value.map { .string($0) }
        default: throw DriverCannot(reading: property, of: element)
        }
    }

    /// What the title area of the window `element` stands in shows: the application's name and the line under it,
    /// nil where the window shows no title area.
    func titleAreaHolds(_ property: Prop, _ element: MountedElement) throws -> HostValue? {
        let controller = try controller(of: element)
        guard controller.titleAccessoryForTesting != nil else { return nil }
        let words = property == .barTitle
            ? controller.titleClusterForTesting.titleForTesting : controller.titleClusterForTesting.subtitleForTesting
        return words.isEmpty ? nil : words.propValue
    }

    /// The colour the bar of the window `element` stands in is painted: the window's own background, which the title
    /// bar lets show only while a colour is painted; nil on the system's material.
    func barHolds(_ element: MountedElement) throws -> HostValue? {
        guard let window = try controller(of: element).window, window.titlebarAppearsTransparent else { return nil }
        return Self.color(window.backgroundColor).propValue
    }

    /// What the host keeps under `key`, as the next launch reads it: a value every scene shares from the driver's
    /// preferences, as its words read back; one of the first scene from its main window's restoration record.
    func kept(_ key: String, inScene: Bool) throws -> HostValue? {
        guard let renderer else { throw DriverCannot("read what is kept before a host runs") }
        if inScene { return renderer.windowsForTesting.first(where: \.isMain)?.restorationRecordForTesting.kept[key] }
        guard let word = store.string(forKey: key) else { return nil }
        let kinds = [
            PersistentKey(key, of: String.self), PersistentKey(key, of: Double.self), PersistentKey(key, of: Bool.self),
        ]
        return kinds.lazy.compactMap { KeptWord.restored([key: word], for: [$0])[key] }.first
    }

    /// The question AppKit's alert shows now, as it shows it.
    func question(over element: MountedElement) throws -> Question? {
        guard let shown = renderer?.actToolkit.showing?.shownForTesting else { return nil }
        return Question(title: shown.title, message: shown.message, buttons: shown.buttons, field: shown.field)
    }

    /// What the host told the screen reader, in order, as it posted it.
    func announced() throws -> [String] {
        renderer?.actToolkit.announcedForTesting ?? []
    }

    /// What the host wrote to its log since it started.
    func logged() throws -> [String] {
        written.lines
    }

    var liveViews: Int? {
        AppKitElement.liveViewCount
    }

    /// The colour the view draws at `point` of its own, as AppKit displays it into a bitmap; nil where it draws
    /// nothing there.
    func color(of element: MountedElement, at point: Point) throws -> Color? {
        guard let view = (element.native as? AppKitElement)?.view else {
            throw DriverCannot("read the colour of \(element.type.name)")
        }
        view.window?.contentView?.layoutSubtreeIfNeeded()
        let size = view.bounds.size
        let (width, height) = (Int(size.width.rounded(.up)), Int(size.height.rounded(.up)))
        // The view displayed into a context of its points in sRGB, which StateUI's colours are: AppKit converts
        // what it draws into it.
        guard point.x >= 0, point.y >= 0, point.x < size.width, point.y < size.height, width > 0, height > 0,
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        view.displayIgnoringOpacity(view.bounds, in: NSGraphicsContext(cgContext: context, flipped: false))
        guard let data = context.data else { return nil }
        // A bitmap context's rows stand in memory from its top.
        let row = min(height - 1, Int(point.y))
        let pixel = data.advanced(by: row * width * 4 + min(width - 1, Int(point.x)) * 4)
            .assumingMemoryBound(to: UInt8.self)
        let alpha = Int(pixel[3])
        guard alpha > 127 else { return nil }
        func channel(_ index: Int) -> Int { min(255, Int(pixel[index]) * 255 / alpha) }
        return Color(red: channel(0), green: channel(1), blue: channel(2))
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
/// The host's log, line by line, as the driver hears it.
final class AppKitLogLines: @unchecked Sendable {
    private(set) var lines: [String] = []

    /// Listens to the host's log from now on.
    @MainActor func listen() {
        lines = []
        AppKitRenderer.log = HostLog(host: "AppKit") { [self] line in
            lines.append(line)
            print(line, terminator: "")
        }
    }
}

#endif
