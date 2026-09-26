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
        let main = NSMenu()
        let applicationItem = NSMenuItem(
            title: ProcessInfo.processInfo.processName, action: nil, keyEquivalent: "")
        let fileItem = NSMenuItem(title: "File", action: nil, keyEquivalent: "")
        let windowItem = NSMenuItem(title: "Window", action: nil, keyEquivalent: "")
        main.addItem(applicationItem)
        main.addItem(fileItem)
        main.addItem(windowItem)

        let applicationMenu = NSMenu()
        applicationMenu.addItem(withTitle: "Quit \(ProcessInfo.processInfo.processName)",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q")
        applicationItem.submenu = applicationMenu

        let fileMenu = NSMenu(title: "File")
        let newWindow = NSMenuItem(
            title: "New Window",
            action: #selector(AppDelegate.newScene(_:)),
            keyEquivalent: "n")
        newWindow.target = delegate
        fileMenu.addItem(newWindow)
        fileItem.submenu = fileMenu

        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize",
                           action: #selector(NSWindow.performMiniaturize(_:)),
                           keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Bring All to Front",
                           action: #selector(NSApplication.arrangeInFront(_:)),
                           keyEquivalent: "")
        windowItem.submenu = windowMenu
        application.windowsMenu = windowMenu
        application.mainMenu = main
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

    func applicationDidBecomeActive(_ notification: Notification) {
        host.applicationBecameActive()
    }

    func applicationDidResignActive(_ notification: Notification) {
        host.applicationResignedActive()
    }

    func applicationDidHide(_ notification: Notification) {
        host.applicationWasHidden()
    }

    func applicationDidUnhide(_ notification: Notification) {
        host.applicationWasUnhidden()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    @objc func newScene(_ sender: Any?) {
        host.openPlatformScene()
    }
}
#endif
