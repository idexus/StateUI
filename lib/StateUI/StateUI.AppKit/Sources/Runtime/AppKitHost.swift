// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
import Foundation
import QuartzCore
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// Runs a StateUI application as native AppKit controls in the current process.
///
/// The host materializes StateUI's application structure, page containers,
/// foundational layouts and controls as AppKit objects. Unsupported controls
/// remain visible as diagnostic labels, so each subsequent adapter can be
/// delivered as a complete vertical slice.
@MainActor
public enum StateUIAppKit {
    /// Starts `NSApplication` and displays the application already registered
    /// with `stateUIUseApp(_:)`.
    ///
    /// - Parameters:
    ///   - resourceDirectory: A directory containing image resources.
    ///   - applicationIcon: The complete image shown for the running application.
    public static func run(
        resourceDirectory: URL? = nil,
        applicationIcon: URL? = nil
    ) {
        let application = NSApplication.shared
        let delegate = AppDelegate(resourceDirectory: resourceDirectory)

        application.setActivationPolicy(.regular)
        if let applicationIcon, let icon = NSImage(contentsOf: applicationIcon) {
            application.applicationIconImage = icon
        }
        application.delegate = delegate
        configureMainMenu(application: application, delegate: delegate)
        application.run()

        withExtendedLifetime(delegate) {}
    }

    private static func configureMainMenu(
        application: NSApplication,
        delegate: AppDelegate
    ) {
        let main = mainMenu(newWindow: delegate)
        application.windowsMenu = main.items.first { $0.identifier == AppKitMenus.identifier(.window) }?.submenu
        application.mainMenu = main
    }

    /// The menu bar every StateUI application stands with: the application's own, File with a new window for
    /// `newScene`, Edit with the text commands a field answers through the responder chain, and Window. A page's
    /// menus join it as it shows.
    /// Design: docs/design/platforms/appkit/runtime.md#the-menu-bar
    static func mainMenu(newWindow: AnyObject?) -> NSMenu {
        let main = NSMenu()
        let name = ProcessInfo.processInfo.processName

        let applicationMenu = NSMenu()
        applicationMenu.addItem(
            withTitle: "Quit \(name)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        main.addItem(submenu: applicationMenu, titled: name)

        let fileMenu = NSMenu(title: "File")
        let newWindowItem = NSMenuItem(
            title: "New Window", action: #selector(AppDelegate.newWindow(_:)), keyEquivalent: "n")
        newWindowItem.target = newWindow
        fileMenu.addItem(newWindowItem)
        main.addItem(submenu: fileMenu, titled: "File", standard: .file)

        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Delete", action: #selector(NSText.delete(_:)), keyEquivalent: "")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        main.addItem(submenu: editMenu, titled: "Edit", standard: .edit)

        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(
            withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(
            withTitle: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        main.addItem(submenu: windowMenu, titled: "Window", standard: .window)
        return main
    }
}

private extension NSMenu {
    /// Adds `submenu` to the bar under `title`, known as the platform's `standard` menu where it is one.
    func addItem(submenu: NSMenu, titled title: String, standard: StandardMenu? = nil) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = submenu
        item.identifier = standard.map(AppKitMenus.identifier)
        addItem(item)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let host: AppKitRenderer

    init(resourceDirectory: URL?) {
        host = AppKitRenderer(resourceDirectory: resourceDirectory)
        super.init()
        AppKitRestorationBroker.shared.host = host
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        host.start()
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        host.reopen(hasVisibleWindows: flag)
        return true
    }

    func applicationDidHide(_ notification: Notification) {
        host.applicationHidden(true)
    }

    func applicationDidUnhide(_ notification: Notification) {
        host.applicationHidden(false)
    }

    func applicationWillTerminate(_ notification: Notification) {
        host.runtime.ending()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    @objc func newWindow(_ sender: Any?) {
        host.openNewWindow()
    }
}
#endif
