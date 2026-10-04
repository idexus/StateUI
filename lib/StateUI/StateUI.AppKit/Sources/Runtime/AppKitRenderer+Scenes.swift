// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// Scenes and windows: kept in step with the tree, restored, activated and closed.
/// Design: docs/design/platforms/appkit/runtime.md#the-window
extension AppKitRenderer {
    /// Composes every window's chrome again from what it shows now - after a
    /// change the user made on a native control, which the application may
    /// not render for.
    func refreshWindowChrome() {
        for controller in windowControllers {
            controller.refreshChrome()
        }
    }

    /// Opens one more window of the group with no name - *File ▸ New Window*, or the Dock with none open.
    func openNewWindow() {
        runtime.connectWindow()
        runtime.pump.turn()
    }

    func reopen(hasVisibleWindows: Bool) {
        if hasVisibleWindows {
            activeWindow?.window?.makeKeyAndOrderFront(nil)
            return
        }

        if let first = windowControllers.first?.window {
            first.makeKeyAndOrderFront(nil)
        } else {
            openNewWindow()
        }
    }

    /// The system hid the whole application, or showed it again: the host layer settles what that means.
    func applicationHidden(_ hidden: Bool) {
        runtime.applicationHidden(hidden)
    }

    /// Shows every window element in an AppKit window of its own, in the tree's order - a window the tree no longer
    /// holds closes, the last first.
    func synchronizeWindows() {
        guard let root = runtime.tree.root, root.type == .application else { return }
        windowSynchronizationCountForTesting += 1

        sceneValues.keep(only: Set(SceneValues.scenes(of: root).map(SceneValues.key(of:))))
        roster.update(root: root, make: makeWindowController, close: { $0.closeFromTree() })
        for (index, (element, controller)) in roster.windows.enumerated() {
            controller.present(element, in: runtime, cascade: index)
        }

        if let window = windowControllers.compactMap(\.window).first {
            frameClock.attach(to: window)
        }
        runtime.displayCycle.hold()
    }

    /// The controller of a window element new here: in the window the system restored for it, where there is one,
    /// its record carrying what its scene keeps.
    private func makeWindowController(_ element: MountedElement) -> AppKitWindowController {
        let restored = self.restored.take(for: element)
        let scene = element.enclosing(type: .scene).map(SceneValues.key(of:)) ?? ""
        return AppKitWindowController(
            element,
            host: self,
            record: WindowRecord(
                of: element, identifier: restored?.record.identifier ?? UUID().uuidString, kept: sceneValues[scene]),
            nativeWindow: restored?.native,
            presentsWindow: presentsWindows)
    }

    /// A scene keeps a value: every window of it writes it in its record, for whichever comes back first.
    func keepSceneValue(_ call: HostActCall) {
        guard let scene = sceneValues.keep(call.arguments) else { return }

        for controller in windowControllers
        where controller.element?.enclosing(type: .scene).map(SceneValues.key(of:)) == scene {
            controller.keepSceneValues(sceneValues[scene])
        }
    }

    /// A window the system restored, in a window of its own, as its kind for its value - nil where no scene declares
    /// it, and the system restores nothing.
    func acceptRestoredWindow(_ record: WindowRecord) -> NSWindow? {
        let window = AppKitWindowController.makeWindow()
        window.isReleasedWhenClosed = false
        window.identifier = NSUserInterfaceItemIdentifier(record.identifier)
        window.isRestorable = true
        window.restorationClass = AppKitWindowRestorer.self

        guard restored.accept(record, native: window, values: &sceneValues, in: runtime) else { return nil }

        connectedFirstWindow = true
        if started { runtime.pump.turn() }
        return window
    }

    /// A window took the keyboard: its page's menus stand in the menu bar, and the host layer settles what it means.
    func windowBecameKey(_ controller: AppKitWindowController) {
        activeWindow = controller
        installPageMenus(controller.pageMenus)
        windowStateChanged(controller)
    }

    /// AppKit told what `controller`'s window does now: the host layer settles what it means for the application,
    /// its scenes and its windows.
    /// Design: docs/design/host/runtime.md#the-applications-phase
    func windowStateChanged(_ controller: AppKitWindowController) {
        guard !controller.closingFromTree, let element = controller.element else { return }
        runtime.windowStateChanged(element, minimized: controller.isMinimized, activated: controller.isKey)
    }

    /// A window closes: one the tree closed tells nothing; one the user closed is heard by it and its scene.
    /// Design: docs/design/host/runtime.md#a-window-the-user-closes
    func windowWillClose(_ controller: AppKitWindowController) {
        if activeWindow === controller {
            activeWindow = nil
            installPageMenus([])
        }

        if let closing = controller.window {
            frameClock.release(closing, next: windowControllers
                .filter { $0 !== controller }
                .compactMap(\.window)
                .first)
        }

        guard !controller.closingFromTree, let element = controller.element else { return }
        runtime.userClosed(element)
    }

    func nativeWindowAvailable(_ window: NSWindow) {
        frameClock.attach(to: window)
    }

    func pageMenusChanged(in controller: AppKitWindowController) {
        guard activeWindow === controller || controller.window?.isKeyWindow == true else { return }
        installPageMenus(controller.pageMenus)
    }

    /// Puts the menus the visible page composes on the menu bar in place of the ones it put there before: a
    /// standard menu joins the platform's own of its identity as a section after its entries, a standard menu the
    /// platform keeps none of stands where the platform's would, and any other stands before Window.
    /// Design: docs/design/platforms/appkit/runtime.md#the-menu-bar
    func installPageMenus(_ menus: [MenuEntry], into main: NSMenu? = NSApplication.shared.mainMenu) {
        for insertion in pageMenuInsertions.reversed() {
            insertion.menu.removeItem(insertion.item)
        }
        pageMenuInsertions.removeAll(keepingCapacity: true)

        // Each entry's own item, kept on its element, stands in the page's menus; the bar takes copies.
        let roots = AppKitMenus.items(menus)
        guard let main else { return }

        for (menu, root) in zip(menus, roots) {
            let standing = menu.standard.flatMap { standard in
                main.items.first { $0.identifier == AppKitMenus.identifier(standard) }?.submenu
            }
            if let target = standing, let source = root.submenu {
                if !target.items.isEmpty {
                    let separator = NSMenuItem.separator()
                    target.addItem(separator)
                    pageMenuInsertions.append((target, separator))
                }

                for sourceItem in source.items {
                    let item = cloneMenuItem(sourceItem)
                    target.addItem(item)
                    pageMenuInsertions.append((target, item))
                }
            } else {
                let item = cloneMenuItem(root)
                item.identifier = menu.standard.map(AppKitMenus.identifier)
                main.insertItem(item, at: AppKitMenus.place(of: menu.standard, in: main))
                pageMenuInsertions.append((main, item))
            }
        }
    }

    func cloneMenuItem(_ source: NSMenuItem) -> NSMenuItem {
        guard !source.isSeparatorItem else { return .separator() }

        let item = NSMenuItem(
            title: source.title,
            action: source.action,
            keyEquivalent: source.keyEquivalent)
        item.target = source.target
        item.setAccessibilityIdentifier(source.accessibilityIdentifier())
        item.attributedTitle = source.attributedTitle
        item.image = source.image
        item.isEnabled = source.isEnabled
        item.state = source.state

        if let sourceMenu = source.submenu {
            let menu = NSMenu(title: sourceMenu.title)
            for child in sourceMenu.items {
                menu.addItem(cloneMenuItem(child))
            }
            item.submenu = menu
        }

        return item
    }

    /// The window controllers, in the tree's order of their windows.
    var windowControllers: [AppKitWindowController] {
        roster.controllers
    }

    func standingWindowValue(for node: AppKitElement, property: Prop) -> HostValue? {
        roster.controller(of: node.element)?.standingValue(property)
    }
}

#endif
