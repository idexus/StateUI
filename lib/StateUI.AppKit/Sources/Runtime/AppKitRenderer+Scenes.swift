// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// Scenes and windows: kept in step with the tree, restored, activated and closed.
extension AppKitRenderer {
    /// Composes every window's chrome again from what it shows now - after a
    /// change the user made on a native control, which the application may
    /// not render for.
    func refreshWindowChrome() {
        for controller in orderedWindowControllers {
            controller.refreshChrome()
        }
    }

    func openPlatformScene() {
        connectPlatformScene(restoring: [:])
        pump()
    }

    func reopen(hasVisibleWindows: Bool) {
        if hasVisibleWindows {
            activeWindow?.window?.makeKeyAndOrderFront(nil)
            return
        }

        if let first = orderedWindowControllers.first?.window {
            first.makeKeyAndOrderFront(nil)
        } else {
            openPlatformScene()
        }
    }

    func applicationBecameActive() {
        core.setApplicationPhase(.active)
        if let activeWindow {
            activeWindow.scene?.report(.activated)
            arrangeOwnedWindows(for: activeWindow.scene)
            installPageMenus(activeWindow.pageMenuItems)
        }
        pump()
    }

    func applicationResignedActive() {
        guard !applicationIsHidden else { return }
        core.setApplicationPhase(.inactive)
        activeWindow?.scene?.report(.deactivated)
        pump()
    }

    func applicationWasHidden() {
        applicationIsHidden = true
        core.setApplicationPhase(.background)

        for scene in orderedScenes {
            scene.applicationWasHidden()
        }

        pump()
    }

    func applicationWasUnhidden() {
        applicationIsHidden = false
        core.setApplicationPhase(.inactive)

        for scene in orderedScenes {
            scene.applicationWasUnhidden()
        }

        pump()
    }

    func connectPlatformScene(restoring values: [String: HostValue]) {
        core.connectScene(restoring: values)
        connectedInitialScene = true
    }

    func synchronizeWindows() {
        guard let root = tree.root, root.type == .application else { return }
        windowSynchronizationCountForTesting += 1

        synchronizingWindows = true
        defer { synchronizingWindows = false }

        let sceneNodes = root.children.filter { $0.type == .scene }
        let nextIDs = sceneNodes.map(\.id)
        let nextSet = Set(nextIDs)

        for id in sceneOrder where !nextSet.contains(id) {
            scenes.removeValue(forKey: id)?.closeFromTree()
        }

        var cascade = 0
        for sceneNode in sceneNodes {
            let scene = scenes[sceneNode.id] ?? AppKitSceneController(
                id: sceneNode.id,
                host: self,
                presentsWindows: presentsWindows,
                restoredMain: takeRestoredMainWindow())
            scenes[sceneNode.id] = scene
            scene.synchronize(sceneNode.appKit, cascadeFrom: cascade)
            cascade += sceneNode.children.filter { $0.type == .window }.count
        }

        sceneOrder = nextIDs

        if let window = orderedWindowControllers.compactMap(\.window).first {
            frameClock.attach(to: window)
        }
        offerRestoredWindows()
        displayCycle.hold()
    }

    func keepSceneValue(_ call: HostActCall) {
        guard call.arguments.count >= 3,
              let sceneID = call.arguments[0].name,
              let name = call.arguments[1].name
        else { return }

        orderedScenes.first { $0.stateUIID == .manual(sceneID) }?
            .keep(name: name, value: call.arguments[2])
    }

    func acceptRestoredWindow(_ record: AppKitRestorationRecord) -> NSWindow {
        if let standing = restoredWindows[record.windowIdentifier] { return standing }

        let window = AppKitWindowController.makeWindow()
        window.isReleasedWhenClosed = false
        window.identifier = NSUserInterfaceItemIdentifier(record.windowIdentifier)
        window.isRestorable = true
        window.restorationClass = AppKitWindowRestorer.self
        window.setFrameAutosaveName("StateUI.\(record.windowIdentifier)")

        restorationQueue.append(record)
        restoredWindows[record.windowIdentifier] = window

        if record.ownerIdentifier == nil {
            connectPlatformScene(restoring: record.kept)
            if started { pump() }
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

    func offerRestoredWindows() {
        for scene in orderedScenes {
            guard let owner = scene.sessionIdentifier,
                  let handler = scene.restoredWindowHandler
            else { continue }

            for record in restorationQueue.owned(by: owner) {
                guard let kind = record.kind,
                      offeredRestorations.insert(record.windowIdentifier).inserted
                else { continue }

                var payload: [HostValue] = [.string(kind)]
                if let value = record.value { payload.append(.string(value)) }
                queuedEvents.append(QueuedEvent(
                    handler: handler,
                    payload: payload,
                    restorationIdentifier: record.windowIdentifier))
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
            let owners = Set(self.orderedScenes.compactMap(\.sessionIdentifier))

            for record in self.restorationQueue.all
            where record.ownerIdentifier.map({ !owners.contains($0) }) ?? false {
                self.declineRestorationIfUnclaimed(record.windowIdentifier)
            }
        }
    }

    func windowBecameKey(_ controller: AppKitWindowController) {
        let previousScene = activeWindow?.scene
        activeWindow = controller
        installPageMenus(controller.pageMenuItems)

        controller.reportWindow(.activated)

        if previousScene !== controller.scene {
            previousScene?.report(.deactivated)
            controller.scene?.report(.activated)
            arrangeOwnedWindows(for: controller.scene)
        }

        core.setApplicationPhase(.active)
    }

    func windowResignedKey(_ controller: AppKitWindowController) {
        controller.reportWindow(.deactivated)

        DispatchQueue.main.async { [weak self, weak controller] in
            guard let self, let controller, self.activeWindow === controller,
                  NSApplication.shared.keyWindow == nil,
                  !self.applicationIsHidden
            else { return }

            controller.scene?.report(.deactivated)
            core.setApplicationPhase(.inactive)
            self.pump()
        }
    }

    func windowWillClose(_ controller: AppKitWindowController) {
        if activeWindow === controller {
            activeWindow = nil
            installPageMenus([])
        }

        if let closing = controller.window {
            frameClock.release(closing, next: orderedWindowControllers
                .filter { $0 !== controller }
                .compactMap(\.window)
                .first)
        }

        guard !controller.closingFromTree else { return }

        controller.reportWindow(.destroying)

        if controller.isMain {
            controller.scene?.report(.destroying)
        } else {
            controller.scene?.report(.windowClosed, payload: [controller.stateUIID.hostPayload])
        }

        DispatchQueue.main.async { [weak self] in
            guard let self, self.orderedWindowControllers.isEmpty,
                  NSApplication.shared.keyWindow == nil,
                  !self.applicationIsHidden
            else { return }

            core.setApplicationPhase(.inactive)
            self.pump()
        }
    }

    func nativeWindowAvailable(_ window: NSWindow) {
        frameClock.attach(to: window)
    }

    func pageMenusChanged(in controller: AppKitWindowController) {
        guard activeWindow === controller || controller.window?.isKeyWindow == true else { return }
        installPageMenus(controller.pageMenuItems)
    }

    /// Replaces only commands contributed by the visible StateUI page. The
    /// standard application, File and Window commands remain host-owned.
    func installPageMenus(_ roots: [NSMenuItem]) {
        for insertion in pageMenuInsertions.reversed() {
            insertion.menu.removeItem(insertion.item)
        }
        pageMenuInsertions.removeAll(keepingCapacity: true)

        guard let main = NSApplication.shared.mainMenu else { return }

        for root in roots {
            if let standing = main.items.first(where: { $0.title == root.title }),
               let target = standing.submenu,
               let source = root.submenu {
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
                let windowIndex = main.items.firstIndex(where: { $0.title == "Window" })
                    ?? main.items.count
                main.insertItem(item, at: windowIndex)
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

    func arrangeOwnedWindows(for front: AppKitSceneController?) {
        for scene in orderedScenes {
            scene.setActive(scene === front)
        }
    }

    var orderedScenes: [AppKitSceneController] {
        sceneOrder.compactMap { scenes[$0] }
    }

    var orderedWindowControllers: [AppKitWindowController] {
        orderedScenes.flatMap(\.orderedWindows)
    }

    func standingWindowValue(
        for node: AppKitElement,
        property: Prop
    ) -> HostValue? {
        orderedWindowControllers.first(where: { $0.presents(node) })?
            .standingValue(property)
    }
}

/// An element's id as a window event carries it.
extension ElementId {
    var hostPayload: HostValue {
        switch self {
        case .manual(let value): .string(value)
        case .auto(let value): .number(Double(value))
        }
    }
}

#endif
