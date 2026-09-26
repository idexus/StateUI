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
        guard let shown = renderer?.actPerformer.showing?.shownForTesting else { return nil }
        return Question(title: shown.title, message: shown.message, buttons: shown.buttons, field: shown.field)
    }

    /// What the host told the screen reader, in order, as it posted it.
    func announced() throws -> [String] {
        renderer?.actPerformer.announcedForTesting ?? []
    }

    /// What the host wrote to its log since it started.
    func logged() throws -> [String] {
        written.lines
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
