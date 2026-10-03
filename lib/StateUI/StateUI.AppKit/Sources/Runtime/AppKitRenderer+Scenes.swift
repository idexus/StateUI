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

    func openPlatformScene() {
        connectPlatformScene(restoring: [:])
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
            openPlatformScene()
        }
    }

    /// The system hid the whole application, or showed it again: the host layer settles what that means.
    func applicationHidden(_ hidden: Bool) {
        runtime.applicationHidden(hidden)
    }

    /// Hands the core a platform scene: one the system restored as its kind, or a new one - the kind File ▸ New
    /// opens.
    func connectPlatformScene(restoring values: [String: HostValue], kind: String? = nil) {
        runtime.core.connectScene(restoring: values, kind: kind)
        connectedInitialScene = true
    }

    /// Shows every window element in an AppKit window of its own, in the tree's order - a window the tree no longer
    /// holds closes, the last first - each scene keeping what its windows are restored by.
    func synchronizeWindows() {
        guard let root = runtime.tree.root, root.type == .application else { return }
        windowSynchronizationCountForTesting += 1

        let scenes = root.children.filter { $0.type == .scene }
        sessions = sessions.filter { id, _ in scenes.contains { $0.id == id } }
        for scene in scenes where sessions[scene.id] == nil {
            sessions[scene.id] = AppKitSceneSession(restoredMain: takeRestoredMainWindow())
        }

        roster.update(root: root, make: makeWindowController, close: { $0.closeFromTree() })
        for (index, (element, controller)) in roster.windows.enumerated() {
            controller.present(element, in: runtime, cascade: index)
        }

        if let window = windowControllers.compactMap(\.window).first {
            frameClock.attach(to: window)
        }
        runtime.displayCycle.hold()
    }

    /// The controller of a window element new here: in the window the system restored for it, where there is one.
    private func makeWindowController(_ element: MountedElement) -> AppKitWindowController {
        let session = element.enclosing(type: .scene).flatMap { sessions[$0.id] }
        let arrival = session?.arrival(of: element) { [unowned self] owner in
            takeRestoredWindow(
                owner: owner, kind: element.name(.windowType), value: element.value(.windowValue)?.string)
        }
        return AppKitWindowController(
            element,
            host: self,
            record: arrival?.record ?? AppKitRestorationRecord(windowIdentifier: UUID().uuidString),
            nativeWindow: arrival?.window,
            presentsWindow: presentsWindows)
    }

    func keepSceneValue(_ call: HostActCall) {
        guard call.arguments.count >= 3,
              let sceneID = call.arguments[0].name,
              let name = call.arguments[1].name,
              let session = sessions[.manual(sceneID)]
        else { return }

        session.keep(name: name, value: call.arguments[2])
        windowControllers.first { $0.isMain && $0.element?.enclosing(type: .scene)?.id == .manual(sceneID) }?
            .keepSceneValues(session.kept)
    }

    func acceptRestoredWindow(_ record: AppKitRestorationRecord) -> NSWindow {
        if let standing = restoredWindows[record.windowIdentifier] { return standing }

        let window = AppKitWindowController.makeWindow()
        window.isReleasedWhenClosed = false
        window.identifier = NSUserInterfaceItemIdentifier(record.windowIdentifier)
        window.isRestorable = true
        window.restorationClass = AppKitWindowRestorer.self

        restorationQueue.append(record)
        restoredWindows[record.windowIdentifier] = window

        if record.ownerIdentifier == nil {
            connectPlatformScene(restoring: record.kept, kind: record.kind)
            if started { runtime.pump.turn() }
        } else if started {
            offerRestoredWindows()
        }

        scheduleRestorationAbandonment()
        return window
    }

    func takeRestoredWindow(
        owner: String,
        kind: String?,
        value: String?
    ) -> AppKitRestoredWindow? {
        guard let record = restorationQueue.takeOwned(by: owner, kind: kind, value: value),
              let window = restoredWindows.removeValue(forKey: record.windowIdentifier)
        else { return nil }

        offeredRestorations.remove(record.windowIdentifier)
        return AppKitRestoredWindow(record: record, window: window)
    }

    func takeRestoredMainWindow() -> AppKitRestoredWindow? {
        guard let record = restorationQueue.takeMain(),
              let window = restoredWindows.removeValue(forKey: record.windowIdentifier)
        else { return nil }

        return AppKitRestoredWindow(record: record, window: window)
    }

    /// Offers each scene the restored windows it owns, each once: the scene's handler hears its kind and value, and
    /// one the next presentation finds no window claiming is declined.
    func offerRestoredWindows() {
        for scene in runtime.tree.root?.children.filter({ $0.type == .scene }) ?? [] {
            guard let owner = sessions[scene.id]?.identifier,
                  let handler = scene.handler(.windowRestored)
            else { continue }

            for record in restorationQueue.owned(by: owner) {
                guard let kind = record.kind,
                      offeredRestorations.insert(record.windowIdentifier).inserted
                else { continue }

                var payload: [HostValue] = [.string(kind)]
                if let value = record.value { payload.append(.string(value)) }
                offersAwaitingClaim.append(record.windowIdentifier)
                runtime.dispatch(handler, payload: payload)
            }
        }
    }

    func declineRestorationIfUnclaimed(_ identifier: String) {
        guard let record = restorationQueue.remove(windowIdentifier: identifier) else { return }
        offeredRestorations.remove(identifier)
        restoredWindows.removeValue(forKey: record.windowIdentifier)?.close()
    }

    func scheduleRestorationAbandonment() {
        guard !abandonmentScheduled else { return }
        abandonmentScheduled = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self else { return }
            self.abandonmentScheduled = false
            let owners = Set(self.sessions.values.compactMap(\.identifier))

            for record in self.restorationQueue.all
            where record.ownerIdentifier.map({ !owners.contains($0) }) ?? false {
                self.declineRestorationIfUnclaimed(record.windowIdentifier)
            }
        }
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
