// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
import Foundation
import QuartzCore
@_spi(Host) import StateUI

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

/// The unchecked promise is narrow: every mutation and every AppKit call is in
/// a `@MainActor` method. The only cross-thread capture posts `pump()` onto the
/// main queue after the blocking doorbell returns.
struct AppKitPresentationImpact: OptionSet {
    let rawValue: UInt8

    static let content = AppKitPresentationImpact(rawValue: 1 << 0)
    static let windowShell = AppKitPresentationImpact(rawValue: 1 << 1)

    /// The element's own layout item changed, so its parent arranges again.
    static let arrangement = AppKitPresentationImpact(rawValue: 1 << 2)
}

@MainActor
final class AppKitRenderer: @unchecked Sendable {
    private struct QueuedEvent {
        let handler: Int32
        let payload: [HostValue]
        let restorationIdentifier: String?

        /// A phase report, rendered before the next report moves the phase
        /// again.
        var isPhase = false
    }

    private let resourceDirectory: URL?
    private let presentsWindows: Bool
    private let eventSink: ((Int32, [HostValue]) -> Void)?
    private let preferences: UserDefaults
    private let core = AppKitCoreLink()
    private let walker: AppKitWalker
    private let stateChannels: AppKitStateChannels
    private let describedMotion: AppKitDescribedMotion
    private let displayCycle: AppKitDisplayCycle
    private let images = NSCache<NSString, NSImage>()
    private let frameClock: AppKitFrameClock
    private let reducesMotion: () -> Bool
    private var baseline: Int32 = 0
    private var nextMount: UInt64 = 0
    private var patchTime: Double?
    private var patchReducesMotion: Bool?
    private var root: MountedNode?
    private var scenes: [ElementId: AppKitSceneController] = [:]
    private var sceneOrder: [ElementId] = []

    /// The scrollers moving or waiting to report, each given the display's
    /// frames until it stands and has said everything.
    private let framedScrollers = NSHashTable<AppKitScrollView>.weakObjects()
    private var doorbellStarted = false
    private var connectedInitialScene = false
    private var started = false
    private var synchronizingWindows = false

    /// Whether the queue is being delivered. A render inside the delivery
    /// queues what it raises behind what already waits, in order.
    private var deliveringEvents = false
    private var readerTransactionDepth = 0
    private var readerTransactionChangedState = false
    private var queuedEvents: [QueuedEvent] = []
    private weak var activeWindow: AppKitWindowController?
    private var applicationIsHidden = false
    private let restorationQueue = AppKitRestorationQueue()
    private var restoredWindows: [String: NSWindow] = [:]
    private var offeredRestorations = Set<String>()
    private var abandonmentScheduled = false
    private var pageMenuInsertions: [(menu: NSMenu, item: NSMenuItem)] = []
    private(set) var windowSynchronizationCountForTesting = 0

    init(
        resourceDirectory: URL?,
        presentsWindows: Bool = true,
        eventSink: ((Int32, [HostValue]) -> Void)? = nil,
        preferences: UserDefaults = .standard,
        clock: (() -> Double)? = nil,
        reducesMotion: @escaping () -> Bool = {
            NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        }
    ) {
        self.resourceDirectory = resourceDirectory
        self.presentsWindows = presentsWindows
        self.eventSink = eventSink
        self.preferences = preferences
        frameClock = clock.map { AppKitFrameClock(now: $0) } ?? AppKitFrameClock()
        self.reducesMotion = reducesMotion
        let walker = AppKitWalker()
        self.walker = walker
        stateChannels = AppKitStateChannels(walker: walker)
        describedMotion = AppKitDescribedMotion(walker: walker)
        displayCycle = AppKitDisplayCycle(
            core: core,
            clock: frameClock,
            walker: walker,
            stateChannels: stateChannels,
            describedMotion: describedMotion,
            reducesMotion: reducesMotion)
        frameClock.onFrame = { [weak self] now in self?.displayCycle.frame(now: now) }
        displayCycle.presenter = self
    }

    func start() {
        startRuntime()
        startDoorbell()
    }

    private func startRuntime() {
        started = true
        configureEnvironment()
        let appearance = NSApplication.shared.effectiveAppearance
            .bestMatch(from: [.darkAqua, .aqua])
        core.setTheme(appearance == .darkAqua ? .dark : .light)
        hydratePersistentState()
        if !connectedInitialScene {
            connectPlatformScene(restoring: [:])
        }
        pump()
    }

    func startForTesting() { startRuntime() }

    private func configureEnvironment() {
        let process = ProcessInfo.processInfo
        let bundle = Bundle.main

        core.setDeviceInfo(HostDeviceInfo(
            formFactor: .desktop,
            platform: "macOS",
            model: machineModel(),
            manufacturer: "Apple",
            name: Host.current().localizedName ?? "",
            versionString: process.operatingSystemVersionString,
            deviceType: .physical))

        if let screen = NSScreen.main {
            let scale = screen.backingScaleFactor
            core.setDisplayInfo(HostDisplayInfo(
                width: screen.frame.width * scale,
                height: screen.frame.height * scale,
                density: scale,
                orientation: screen.frame.width >= screen.frame.height ? .landscape : .portrait,
                rotation: .rotation0,
                refreshRate: Double(screen.maximumFramesPerSecond)))
        }

        core.setApplicationInfo(HostApplicationInfo(
            name: bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                ?? process.processName,
            packageName: bundle.bundleIdentifier ?? "",
            versionString: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString")
                as? String ?? "",
            buildString: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""))
    }

    private func machineModel() -> String {
        var size = 0
        guard sysctlbyname("hw.model", nil, &size, nil, 0) == 0, size > 0 else { return "" }

        var bytes = [CChar](repeating: 0, count: size)
        guard sysctlbyname("hw.model", &bytes, &size, nil, 0) == 0 else { return "" }
        let end = bytes.firstIndex(of: 0) ?? bytes.endIndex
        return String(decoding: bytes[..<end].map(UInt8.init(bitPattern:)), as: UTF8.self)
    }

    func dispatch(_ handler: Int32, payload: [HostValue] = [], isPhase: Bool = false) {
        if synchronizingWindows || readerTransactionDepth > 0 {
            queuedEvents.append(QueuedEvent(
                handler: handler,
                payload: payload,
                restorationIdentifier: nil,
                isPhase: isPhase))
            return
        }

        if let eventSink {
            eventSink(handler, payload)
            return
        }

        _ = core.dispatch(handler, payload: payload)
        pump()
    }

    /// Defers a platform notification until the current tree is fully applied.
    /// Page visibility can change while children are being reconciled; running
    /// Swift from inside that mutation would make the next render observe a
    /// half-old, half-new native tree.
    func enqueue(_ handler: Int32, payload: [HostValue] = [], isPhase: Bool = false) {
        queuedEvents.append(QueuedEvent(
            handler: handler,
            payload: payload,
            restorationIdentifier: nil,
            isPhase: isPhase))
    }

    /// Composes every window's chrome again from what it shows now - after a
    /// change the reader made on a native control, which the application may
    /// not render for.
    func refreshWindowChrome() {
        for controller in orderedWindowControllers {
            controller.refreshChrome()
        }
    }

    /// Commits a reader-driven page change and its lifecycle as one ordered
    /// batch. The native control has already settled before this is called.
    func commit(_ handler: Int32?, payload: [HostValue] = []) {
        if let handler { enqueue(handler, payload: payload) }
        if !synchronizingWindows, readerTransactionDepth == 0 { flushQueuedEvents() }
    }

    /// Makes a compound reader gesture visible to Swift as one settled native
    /// transaction. Radio groups use it to report the old false before the new
    /// true without rendering between those two halves.
    func performReaderTransaction(_ body: () -> Void) {
        readerTransactionDepth += 1
        body()
        readerTransactionDepth -= 1

        guard readerTransactionDepth == 0, !synchronizingWindows else { return }
        let changedState = readerTransactionChangedState
        readerTransactionChangedState = false

        if !queuedEvents.isEmpty {
            flushQueuedEvents()
        } else if changedState, eventSink == nil {
            pump()
        }
    }

    func settleReaderWrite(_ changedState: Bool) {
        guard changedState, readerTransactionDepth == 0 else { return }
        if eventSink == nil { pump() }
    }

    /// Keeps the display's frames coming for `scroller` until it stands and
    /// has said everything - see `AppKitScrollView.frame(now:)`.
    fileprivate func requestFrames(for scroller: AppKitScrollView) {
        framedScrollers.add(scroller)
        displayCycle.hold()
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

    private func connectPlatformScene(restoring values: [String: HostValue]) {
        core.connectScene(restoring: values)
        connectedInitialScene = true
    }

    @discardableResult
    func report(_ value: HostStateValue, through binding: HostStateBinding) -> Bool {
        guard core.report(value, through: binding) else { return false }

        if readerTransactionDepth > 0 { readerTransactionChangedState = true }

        displayCycle.drain(now: frameClock.now(), reported: [binding.state: value])
        return true
    }

    @discardableResult
    func take(_ value: [Double], through binding: HostStateBinding) -> Bool {
        guard stateChannels.take(value, through: binding) else { return false }

        displayCycle.drain(now: frameClock.now())
        return true
    }

    /// Reads a numerical state named directly by a gesture channel.
    func standingGestureValue(state: Int32) -> Double? {
        core.gestureValue(state: state)
    }

    @discardableResult
    func takeGestureValue(_ value: Double, state: Int32) -> Bool {
        guard core.moveGestureValue(value, state: state) else { return false }
        displayCycle.drain(now: frameClock.now())
        return true
    }

    func pump() {
        _ = core.runJobs()

        for call in core.takeActCalls() {
            switch call.act {
            case .persistValue:
                savePersistent(call)

            case .persistSceneValue:
                keepSceneValue(call)

            case .handlerFailed:
                NSLog("StateUI AppKit: a handler failed: %@", call.arguments.first?.string ?? "")

            default:
                // An act this host does not perform: a caller waiting on it
                // throws the reason, and one nobody waits for is logged, so
                // neither passes in silence.
                let reason = "the AppKit host does not perform the act '\(call.act.name)'"

                if let completion = call.completion {
                    core.fail(completion, reason: reason)
                } else {
                    NSLog("StateUI AppKit: %@", reason)
                }
            }
        }

        if root != nil, core.cyclesPending {
            displayCycle.drain(now: frameClock.now())
        }

        guard root == nil || core.needsRender else { return }

        let rendered = core.render(baseline: baseline)

        applyRoot(rendered.root)

        baseline = rendered.generation
        stateChannels.retain(root?.propertyStates ?? [])
        describedMotion.retain(root?.describedKeys ?? [])
        displayCycle.presentStateChannels()

        let created = root?.takeCreatedHandlers() ?? []
        if !created.isEmpty {
            for handler in created {
                _ = core.dispatch(handler)
            }
            pump()
            return
        }

        synchronizeWindows()
        flushQueuedEvents()
    }

    private func startDoorbell() {
        guard !doorbellStarted else { return }
        doorbellStarted = true

        DispatchQueue.global(qos: .userInteractive).async { [self] in
            while true {
                _ = core.waitForWork()
                DispatchQueue.main.async { [self] in pump() }
            }
        }
    }

    private func synchronizeWindows() {
        guard let root, root.type == .application else { return }
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
            scene.synchronize(sceneNode, cascadeFrom: cascade)
            cascade += sceneNode.children.filter { $0.type == .window }.count
        }

        sceneOrder = nextIDs

        if let window = orderedWindowControllers.compactMap(\.window).first {
            frameClock.attach(to: window)
        }
        offerRestoredWindows()
        displayCycle.hold()
    }

    /// Delivers what waits, in order. A phase is state the application
    /// watches, so each phase report is rendered before the next report moves
    /// the phase again: a push that reports a page's arrival and its
    /// navigation in one native move still shows both.
    private func flushQueuedEvents() {
        guard !deliveringEvents, !queuedEvents.isEmpty else { return }
        deliveringEvents = true
        var restored: [String] = []

        while !queuedEvents.isEmpty {
            let event = queuedEvents.removeFirst()
            if let eventSink {
                eventSink(event.handler, event.payload)
            } else {
                _ = core.dispatch(event.handler, payload: event.payload)
            }
            if let identifier = event.restorationIdentifier { restored.append(identifier) }
            if event.isPhase, eventSink == nil { pump() }
        }

        deliveringEvents = false
        if eventSink == nil { pump() }

        for identifier in restored {
            declineRestorationIfUnclaimed(identifier)
        }
    }

    func keepSceneValue(_ call: HostActCall) {
        guard call.arguments.count >= 3,
              let sceneID = call.arguments[0].name,
              let name = call.arguments[1].name
        else { return }

        orderedScenes.first { $0.stateUIID == .manual(sceneID) }?
            .keep(name: name, value: call.arguments[2])
    }

    func hydratePersistentState() {
        guard core.persistentStorage == .preferences else {
            if !core.persistentKeys.isEmpty {
                NSLog(
                    "StateUI AppKit: no store is registered as %@; kept state uses its declared values",
                    core.persistentStorage.name)
            }
            return
        }

        var restored: [String: HostValue] = [:]

        for key in core.persistentKeys {
            guard preferences.object(forKey: key.name) != nil else { continue }

            switch key.kind {
            case .boolean:
                restored[key.name] = .bool(preferences.bool(forKey: key.name))
            case .integer, .number:
                restored[key.name] = .number(preferences.double(forKey: key.name))
            case .text:
                if let value = preferences.string(forKey: key.name) {
                    restored[key.name] = .string(value)
                }
            }
        }

        core.restorePersistent(restored)
    }

    func savePersistent(_ call: HostActCall) {
        guard core.persistentStorage == .preferences,
              call.arguments.count >= 2,
              let name = call.arguments[0].name,
              let key = core.persistentKeys.first(where: { $0.name == name })
        else { return }

        let value = call.arguments[1]
        switch key.kind {
        case .boolean:
            if let value = value.bool { preferences.set(value, forKey: name) }
        case .integer:
            if let value = value.number { preferences.set(Int64(value), forKey: name) }
        case .number:
            if let value = value.number { preferences.set(value, forKey: name) }
        case .text:
            if let value = value.string { preferences.set(value, forKey: name) }
        }
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

    private func takeRestoredMainWindow() -> AppKitRestoredWindow? {
        guard let record = restorationQueue.takeMain(),
              let window = restoredWindows.removeValue(forKey: record.windowIdentifier)
        else { return nil }

        return AppKitRestoredWindow(record: record, window: window)
    }

    private func offerRestoredWindows() {
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

    private func declineRestorationIfUnclaimed(_ identifier: String) {
        guard let record = restorationQueue.remove(windowIdentifier: identifier) else { return }
        offeredRestorations.remove(identifier)
        restoredWindows.removeValue(forKey: record.windowIdentifier)?.close()
    }

    private func scheduleRestorationAbandonment() {
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
    private func installPageMenus(_ roots: [NSMenuItem]) {
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

    private func cloneMenuItem(_ source: NSMenuItem) -> NSMenuItem {
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

    private func arrangeOwnedWindows(for front: AppKitSceneController?) {
        for scene in orderedScenes {
            scene.setActive(scene === front)
        }
    }

    private var orderedScenes: [AppKitSceneController] {
        sceneOrder.compactMap { scenes[$0] }
    }

    var sceneCountForTesting: Int { scenes.count }

    private var orderedWindowControllers: [AppKitWindowController] {
        orderedScenes.flatMap(\.orderedWindows)
    }

    var windowsForTesting: [AppKitWindowController] { orderedWindowControllers }

    var frameClockWindowForTesting: NSWindow? { frameClock.window }

    var describedMotionActiveForTesting: Bool { describedMotion.isActive }

    func viewForTesting(id: ElementId) -> NSView? {
        root?.first(id: id)?.view
    }

    func viewsForTesting(id: ElementId) -> [NSView] {
        root?.all(id: id).compactMap(\.view) ?? []
    }

    func applyForTesting(_ patch: HostPatch) {
        applyRoot(patch)

        describedMotion.retain(root?.describedKeys ?? [])
        synchronizeWindows()
        flushQueuedEvents()
    }

    private func applyRoot(_ patch: HostPatch) {
        let previousPatchTime = patchTime
        let previousPatchReducesMotion = patchReducesMotion
        if patchTime == nil { patchTime = frameClock.now() }
        if patchReducesMotion == nil { patchReducesMotion = reducesMotion() }
        defer {
            patchTime = previousPatchTime
            patchReducesMotion = previousPatchReducesMotion
        }

        if let root, root.id == patch.id, root.type == patch.type, !patch.replace {
            root.apply(patch)
        } else {
            root = MountedNode(patch, host: self)
        }
    }

    func stepTripsForTesting() {
        displayCycle.stepTrips(now: frameClock.now(), reducesMotion: reducesMotion())
        displayCycle.hold()
    }

    func displayFrameForTesting() {
        displayCycle.frame(now: frameClock.now())
    }

    var frameClockRunningForTesting: Bool { frameClock.isRunning }

    func applyStateForTesting(_ state: Int32, value: HostStateValue) {
        let impact = root?.applyState(state, value: value) ?? []
        if impact.contains(.windowShell) { synchronizeWindows() }
    }

    func applyStatesForTesting(_ valuesByState: [Int32: HostStateValue]) {
        let impact = valuesByState.isEmpty
            ? []
            : (root?.applyStates(valuesByState) ?? [])
        if impact.contains(.windowShell) { synchronizeWindows() }
    }

    func closeForTesting() {
        for scene in orderedScenes.reversed() { scene.closeFromTree() }
        scenes.removeAll()
        sceneOrder.removeAll()
        for window in restoredWindows.values { window.close() }
        restoredWindows.removeAll()
        describedMotion.retain([])
        frameClock.stop()
    }

    fileprivate func presentedValue(
        for binding: HostStateBinding,
        from carried: HostStateValue
    ) -> HostStateValue {
        stateChannels.presentedValue(
            for: binding,
            from: carried,
            now: frameClock.now(),
            reducesMotion: reducesMotion())
    }

    fileprivate func allocateMount() -> UInt64 {
        precondition(nextMount < .max, "AppKit mounted identity exhausted")
        nextMount += 1
        return nextMount
    }

    /// The native image for one resource name, loaded once for this
    /// renderer. Reapplying an unchanged source hands a native view the image
    /// it already shows, so nothing reads the file again and no measurement is
    /// forgotten.
    fileprivate func image(named name: String) -> NSImage? {
        if let kept = images.object(forKey: name as NSString) { return kept }
        guard let loaded = loadImage(named: name) else { return nil }
        images.setObject(loaded, forKey: name as NSString)
        return loaded
    }

    private func loadImage(named name: String) -> NSImage? {
        let url = resourceDirectory?.appendingPathComponent(name)

        if let url, let image = NSImage(contentsOf: url) {
            return image
        }

        if let url, url.pathExtension.lowercased() == "png" {
            let svg = url.deletingPathExtension().appendingPathExtension("svg")
            if let image = NSImage(contentsOf: svg) { return image }
        }

        return NSImage(systemSymbolName: "swift", accessibilityDescription: name)
    }

    fileprivate func presentedPropertyValue(mount: UInt64, property: Prop) -> HostValue? {
        describedMotion.presentedValue(for: AppKitDescribedKey(
            mount: mount,
            property: property))
    }

    fileprivate func receiveProperty(
        mount: UInt64,
        property: Prop,
        standing: HostValue?,
        target: HostValue?,
        transition: HostTransition?
    ) {
        describedMotion.receive(
            key: AppKitDescribedKey(mount: mount, property: property),
            standing: standing,
            target: target,
            transition: transition,
            now: patchTime ?? frameClock.now(),
            reducesMotion: patchReducesMotion ?? reducesMotion())
        displayCycle.hold()
    }

    fileprivate func removePropertyMotions(mount: UInt64) {
        describedMotion.remove(mount: mount)
    }

    fileprivate func standingWindowValue(
        for node: MountedNode,
        property: Prop
    ) -> HostValue? {
        orderedWindowControllers.first(where: { $0.presents(node) })?
            .standingValue(property)
    }

}

extension AppKitRenderer: AppKitFramePresenter {
    var wantsFrames: Bool { framedScrollers.anyObject != nil }

    /// Lets every moving scroller say what the frame saw it do, all of them as
    /// one reader transaction; a scroller that stands and has said everything
    /// lets the clock go.
    func commitReaderReports(now: Double) {
        let scrollers = framedScrollers.allObjects
        guard !scrollers.isEmpty else { return }

        performReaderTransaction {
            for scroller in scrollers {
                scroller.frame(now: now)
                if !scroller.wantsFrames { framedScrollers.remove(scroller) }
            }
        }
    }

    func present(states: [Int32: HostStateValue], properties: [UInt64: Set<Prop>]) {
        let impact = root?.applyFrame(states: states, properties: properties) ?? []
        if impact.contains(.windowShell) { synchronizeWindows() }
    }

    func renderIfNeeded() {
        if eventSink == nil, core.needsRender { pump() }
    }
}

/// Why a page became visible or stopped being visible.
///
/// A navigation move carries the three navigation phases. Window and tab
/// presentation are appearances, so they deliberately carry only the two
/// visibility phases.
enum AppKitPagePresentationReason {
    case appearance
    case navigation
    case window
}

@MainActor
final class MountedNode: NSObject {
    private(set) var id: ElementId
    private(set) var type: NodeType
    private(set) var view: NSView?

    /// How StateUI draws the view over the frame AppKit gives it.
    private var drawing: AppKitViewDrawing?

    private weak var host: AppKitRenderer?
    private let core = AppKitCoreLink()
    private weak var parent: MountedNode?
    private let mount: UInt64
    private var properties: [Prop: HostValue] = [:]
    private var driven: [Prop: HostStateBinding] = [:]
    private var drivenValues: [Prop: HostStateValue] = [:]
    private var events: [Event: Int32] = [:]
    private(set) var children: [MountedNode] = []
    private var recycledChildren: [MountedNode] = []
    private var recycles = false
    private var shape: UInt64 = 0
    private var created = false
    private var widthConstraint: NSLayoutConstraint?
    private var heightConstraint: NSLayoutConstraint?
    private var minimumWidthConstraint: NSLayoutConstraint?
    private var minimumHeightConstraint: NSLayoutConstraint?
    private var maximumWidthConstraint: NSLayoutConstraint?
    private var maximumHeightConstraint: NSLayoutConstraint?
    private var buttonWidthConstraint: NSLayoutConstraint?
    private var buttonHeightConstraint: NSLayoutConstraint?
    private var observesFrame = false
    private var frameObservedViews: [NSView] = []
    private var frameQueued = false
    private var lastFrameReport: [Double]?
    private var tapRecognizer: AppKitTapRecognizer?
    private var swipeRecognizer: AppKitSwipeRecognizer?
    private var panRecognizer: AppKitPanRecognizer?
    private var pinchRecognizer: AppKitPinchRecognizer?
    private var pointerRecognizer: AppKitPointerRecognizer?
    private var accessibilityDefaults: (
        isElement: Bool,
        role: NSAccessibility.Role?
    )?
    private var accessibilityThroughCell: Bool?
    private var accessibilityChildrenSuppressed = false
    private var panFromX: Double = 0
    private var panFromY: Double = 0
    private var pagePresented = false
    private var pendingTabFallback: Int?
    private var platformMenuItem: NSMenuItem?

    init(
        _ patch: HostPatch,
        host: AppKitRenderer,
        parent: MountedNode? = nil
    ) {
        id = patch.id
        type = patch.type
        self.host = host
        self.parent = parent
        mount = host.allocateMount()
        super.init()

        view = makeView()
        drawing = view.map { AppKitViewDrawing($0) }
        apply(patch)
    }

    func apply(_ patch: HostPatch) {
        apply(patch, adopting: false)
    }

    /// Gives a complete arriving row to a native subtree retained by a
    /// recycling layout. The row shape guarantees that types, property keys,
    /// event keys and child positions line up; identities and values do not,
    /// so all of those are stamped from the arriving patch.
    private func apply(_ patch: HostPatch, adopting: Bool) {
        guard let host else { return }

        let previousShown = shownChildren
        var changed: Set<Prop>

        if adopting {
            changed = Set(properties.keys)
            changed.formUnion(patch.properties.keys)
            changed.formUnion(driven.keys)
            if case .replace(let replacement)? = patch.driven {
                changed.formUnion(replacement.keys)
            }
        } else {
            changed = Set(patch.clearedProperties)
            changed.formUnion(patch.properties.keys)
            if case .replace(let replacement) = patch.driven {
                changed.formUnion(driven.keys)
                changed.formUnion(replacement.keys)
            }
        }

        let standing = Dictionary(uniqueKeysWithValues: changed.compactMap { property in
            standingValue(property, target: patch.properties[property]).map { (property, $0) }
        })

        if adopting {
            host.removePropertyMotions(mount: mount)
            id = patch.id
        }
        type = patch.type

        if adopting {
            properties = patch.properties
            if case .replace(let replacement)? = patch.events {
                events = replacement
            } else {
                events = [:]
            }
            if case .replace(let replacement)? = patch.driven {
                driven = replacement
            } else {
                driven = [:]
            }
            drivenValues.removeAll(keepingCapacity: true)
            created = false
            lastFrameReport = nil
            pagePresented = false
            pendingTabFallback = nil
            recycledChildren.removeAll(keepingCapacity: true)
        } else {
            for property in patch.clearedProperties {
                properties[property] = nil
            }

            for (property, value) in patch.properties {
                properties[property] = value
            }

            if case .replace(let events) = patch.events {
                self.events = events
            }
        }

        if !adopting, case .replace(let driven) = patch.driven {
            self.driven = driven
            drivenValues = drivenValues.filter { driven[$0.key] != nil }
        }

        for (property, binding) in driven where binding.mode != .in {
            drivenValues[property] = core.value(for: binding)
        }

        if let recycles = patch.recycles { self.recycles = recycles }
        if let shape = patch.shape { self.shape = shape }
        if !recycles { recycledChildren.removeAll(keepingCapacity: true) }

        switch patch.children {
        case .unchanged:
            break

        case .arranged(let childPatches):
            arrange(childPatches, host: host, adopting: adopting)

        case .changed(let childPatches):
            for childPatch in childPatches {
                if let index = children.firstIndex(where: { $0.id == childPatch.id }) {
                    let child = children[index]

                    if child.type == childPatch.type, !childPatch.replace {
                        child.apply(childPatch)
                    } else {
                        children[index] = MountedNode(
                            childPatch, host: host, parent: self)
                    }
                } else {
                    children.append(MountedNode(
                        childPatch, host: host, parent: self))
                }
            }
        }

        for property in changed.sorted() {
            let hasDrivenPresentation = driven[property].map { $0.mode != .in } ?? false
            host.receiveProperty(
                mount: mount,
                property: property,
                standing: standing[property],
                target: resolvedValue(property),
                transition: adopting || hasDrivenPresentation
                    || !AppKitTransitionSurface.presents(property, on: type)
                    ? nil
                    : patch.transitions[property])
        }

        applyProperties(changed: changed)
        configureContextMenu()
        configureGestures()
        arrangeChildren()
        configureFrameObservation()
        reconcilePresentation(from: previousShown)
        reportTabFallback()
    }

    /// Reconciles a complete child arrangement. Ordinary children match by
    /// identity. During adoption descendants match by position, because the
    /// matching shape already proved the two complete subtrees equivalent.
    private func arrange(
        _ patches: [HostPatch],
        host: AppKitRenderer,
        adopting: Bool
    ) {
        if adopting {
            let previous = children
            children = patches.enumerated().map { index, patch in
                guard index < previous.count,
                      previous[index].type == patch.type,
                      !patch.replace
                else {
                    return MountedNode(patch, host: host, parent: self)
                }

                let child = previous[index]
                child.parent = self
                child.apply(patch, adopting: true)
                return child
            }
            return
        }

        let previous = Dictionary(uniqueKeysWithValues: children.map { ($0.id, $0) })

        if recycles {
            let named = Set(patches.map(\.id))
            for child in children where !named.contains(child.id) {
                guard child.shape != 0,
                      recycledChildren.count < Self.recyclingCapacity
                else { continue }
                child.setRecycled(true)
                recycledChildren.append(child)
            }
        }

        children = patches.map { patch in
            if let child = previous[patch.id], child.type == patch.type, !patch.replace {
                child.parent = self
                child.apply(patch)
                return child
            }

            if recycles, let shape = patch.shape, shape != 0,
               let index = recycledChildren.lastIndex(where: { $0.shape == shape }) {
                let child = recycledChildren.remove(at: index)
                child.parent = self
                child.setRecycled(false)
                child.apply(patch, adopting: true)
                return child
            }

            return MountedNode(patch, host: host, parent: self)
        }
    }

    private func setRecycled(_ recycled: Bool) {
        for native in presentableViews { native.isHidden = recycled }
    }

    func first(type sought: NodeType) -> MountedNode? {
        if type == sought { return self }

        for child in children {
            if let found = child.first(type: sought) { return found }
        }

        return nil
    }

    func first(id sought: ElementId) -> MountedNode? {
        if id == sought { return self }

        for child in children {
            if let found = child.first(id: sought) { return found }
        }

        return nil
    }

    func all(id sought: ElementId) -> [MountedNode] {
        var found = id == sought ? [self] : []
        for child in children {
            found.append(contentsOf: child.all(id: sought))
        }
        return found
    }

    var propertyStates: Set<Int32> {
        var states = Set(driven.values.lazy.filter { $0.kind == .property }.map(\.state))

        for child in children {
            states.formUnion(child.propertyStates)
        }

        return states
    }

    var describedKeys: Set<AppKitDescribedKey> {
        var keys = Set(properties.keys.lazy.filter { property in
            self.driven[property].map { $0.mode == .in } ?? true
        }.map {
            AppKitDescribedKey(mount: self.mount, property: $0)
        })

        for child in children {
            keys.formUnion(child.describedKeys)
        }

        return keys
    }

    /// Presents one frame in one walk: the states' images on the properties
    /// tied to them and the described properties that moved, each element's
    /// together, and each ancestor arranged once.
    @discardableResult
    func applyFrame(
        states valuesByState: [Int32: HostStateValue],
        properties propertiesByMount: [UInt64: Set<Prop>]
    ) -> AppKitPresentationImpact {
        var changed = propertiesByMount[mount] ?? []

        for (property, binding) in driven where binding.mode != .in {
            guard let value = valuesByState[binding.state] else { continue }
            drivenValues[property] = value
            changed.insert(property)
        }

        let own: AppKitPresentationImpact = changed.isEmpty ? [] : presentFrame(changed)
        var descendants: AppKitPresentationImpact = []

        for child in children {
            descendants.formUnion(
                child.applyFrame(states: valuesByState, properties: propertiesByMount))
        }

        return settleFrame(own, descendants: descendants)
    }

    /// Presents one display frame of this element's own changed properties.
    private func presentFrame(_ properties: Set<Prop>) -> AppKitPresentationImpact {
        applyProperties(changed: properties)

        var impact: AppKitPresentationImpact = .content
        // An element without a native view - a span, a formatted string - is
        // drawn by the nearest ancestor that has one, which arranges again. A
        // layout's own placement run moves its children inside the room it
        // already has, so it arranges the layout and not its parent.
        let arranged = properties.subtracting(ownPlacementRun)
        if view == nil || !arranged.isDisjoint(with: Self.arrangedProperties) {
            impact.insert(.arrangement)
        }
        if needsWindowSynchronization(for: properties) {
            impact.insert(.windowShell)
        }
        return impact
    }

    /// Arranges this element once its descendants have their frame, and says
    /// what the frame asks of its parent.
    ///
    /// A child's layout item is its parent's business alone. The ancestors
    /// above learn of a changed size through the measurements the change
    /// forgot, so a frame that moves presentation only arranges nothing, and a
    /// frame that moves a size arranges the one parent that places it. An
    /// element without a view draws nothing itself, so a child's arrangement
    /// passes through it to the element that presents them both.
    private func settleFrame(
        _ own: AppKitPresentationImpact,
        descendants: AppKitPresentationImpact
    ) -> AppKitPresentationImpact {
        if own.contains(.content) || descendants.contains(.arrangement) {
            arrangeChildren()
        }
        guard view != nil else { return own.union(descendants) }
        return own.union(descendants.subtracting(.arrangement))
    }

    var pageView: NSView? {
        pageNode?.presentableViews.first
    }

    var presentablePageView: NSView? { presentableViews.first }

    var pageNode: MountedNode? {
        children.first(where: { Self.pageTypes.contains($0.type) })
    }

    var modalStackNode: MountedNode? {
        children.first { $0.type == .modalStack }
    }

    var overlayItem: AppKitLayoutItem? {
        slot(.overlay)?.children.first?.layoutItem
    }

    var visiblePage: MountedNode? {
        switch type {
        case .page:
            return self
        case .navigationStack:
            return children.last?.visiblePage
        case .tabbedView:
            return selectedTab?.visiblePage
        case .splitView:
            return children.dropFirst().first?.visiblePage
        default:
            return pageNode?.visiblePage
        }
    }

    /// The native navigation container currently surrounding the visible
    /// content, if this page arrangement has one.
    var visibleNavigationStack: MountedNode? {
        switch type {
        case .navigationStack:
            return self
        case .tabbedView:
            return selectedTab?.visibleNavigationStack
        case .splitView:
            return children.dropFirst().first?.visibleNavigationStack
        default:
            return pageNode?.visibleNavigationStack
        }
    }

    /// The colour written for the bars over the visible content: its
    /// navigation stack's, else its tabbed view's.
    var visibleBarBackground: NSColor? {
        visibleNavigationStack?.color(.barBackgroundColor)
            ?? visibleTabbedView?.color(.barBackgroundColor)
    }

    /// The colour written for what stands on those bars.
    var visibleBarForeground: NSColor? {
        visibleNavigationStack?.color(.barForegroundColor)
    }

    /// The tabs the window shows beneath its toolbar - those of the tabbed
    /// view on the visible page path, where its tabs are the window's - and
    /// the split view whose detail it stands in, if any.
    var visibleWindowTabs: AppKitTabsPlacement? {
        guard let tabbed = visibleTabbedView,
              let tabs = tabbed.view as? AppKitTabbedView,
              tabs.tabsShownByWindow
        else { return nil }

        var ancestor = tabbed.parent
        while let node = ancestor, node.type != .splitView {
            ancestor = node.parent
        }

        let segments = tabs.segments
        return AppKitTabsPlacement(
            tabs: AppKitWindowTabs(
                titles: segments.map(\.title),
                images: segments.map(\.image),
                selected: tabs.selectedIndex,
                select: { [weak tabs] index in tabs?.selectByReader(index) }),
            split: ancestor?.view as? AppKitSplitView)
    }

    /// The first tabbed view on the visible page path.
    private var visibleTabbedView: MountedNode? {
        switch type {
        case .page:
            return nil
        case .tabbedView:
            return self
        case .navigationStack:
            return children.last?.visibleTabbedView
        case .splitView:
            return children.dropFirst().first?.visibleTabbedView
        default:
            return pageNode?.visibleTabbedView
        }
    }

    /// Tells each tabbed view on this page path that its tabs are the
    /// window's, in the row beneath its toolbar: the first tabbed view down
    /// any path of stacks and split view details - the row stands beside a
    /// sidebar, never over it. Asked of the window's page once the whole tree
    /// is arranged, so what stands where is the tree's final word. A tabbed
    /// view in a sidebar, a sheet, a tab of another or inside content is never
    /// told, and keeps its tabs on its own content.
    func markTabsShownByWindow() {
        switch type {
        case .tabbedView:
            (view as? AppKitTabbedView)?.tabsShownByWindow = true
        case .navigationStack:
            children.forEach { $0.markTabsShownByWindow() }
        case .splitView:
            children.dropFirst().forEach { $0.markTabsShownByWindow() }
        default:
            break
        }
    }

    /// The native split view controller of a split page.
    var sidebarController: NSSplitViewController? {
        (view as? AppKitSplitView)?.splitController
    }

    /// The way back the visible navigation stack offers, while its top page
    /// can go back.
    var visibleBackAction: AppKitToolbarAction? {
        guard let navigation = visibleNavigationStack,
              navigation.children.count > 1,
              let top = navigation.children.last,
              top.bool(.hasNavigationBar) ?? true,
              top.bool(.hasBackButton) ?? true
        else { return nil }

        let previous = navigation.children[navigation.children.count - 2]
        let title = previous.string(.backButtonTitle) ?? "Back"
        return AppKitToolbarAction(
            identifier: AppKitWindowToolbar.back,
            title: title,
            image: AppKitWindowToolbar.backImage,
            isEnabled: true,
            perform: { [weak navigation] in navigation?.popNavigation() })
    }

    /// The visible page's actions: the primary ones, then those behind
    /// native overflow, each group by priority and then source order. A page
    /// that hides its navigation furniture puts none of them in the toolbar.
    var visibleToolbarActions: (primary: [AppKitToolbarAction], overflow: [AppKitToolbarAction]) {
        guard let page = visiblePage,
              page.bool(.hasNavigationBar) ?? true,
              let items = page.slot(.toolbarItems)?.children
        else { return ([], []) }

        let ordered = items.enumerated().sorted {
            let left = $0.element.whole(.priority) ?? 0
            let right = $1.element.whole(.priority) ?? 0
            return left == right ? $0.offset < $1.offset : left < right
        }.map(\.element)
        let actions = ordered.map { item in
            (overflows: item.enumeration(.placement) == 2, action: AppKitToolbarAction(
                identifier: NSToolbarItem.Identifier("StateUI.action.\(item.mount)"),
                title: item.string(.text) ?? "",
                image: item.image(.icon),
                isEnabled: item.bool(.isEnabled) ?? true,
                perform: { [weak item] in item?.clicked(nil) }))
        }
        return (
            actions.filter { !$0.overflows }.map(\.action),
            actions.filter(\.overflows).map(\.action))
    }

    /// The view the visible page shows in place of its title.
    var visibleTitleView: NSView? {
        visiblePage?.slot(.titleView)?.presentableViews.first
    }

    var pageMenuItems: [NSMenuItem] {
        visiblePage?.slot(.menuBar)?.children.compactMap { $0.nativeMenuItem } ?? []
    }

    /// Makes this page tree visible or hidden, reporting phases only after the
    /// native tree has reached the same state.
    func setPagePresented(_ presented: Bool, reason: AppKitPagePresentationReason) {
        guard Self.pageTypes.contains(type), pagePresented != presented else { return }
        pagePresented = presented

        switch type {
        case .page:
            if presented {
                announce(.appearing)
                if reason == .navigation { announce(.navigatedTo) }
            } else {
                if reason == .navigation { announce(.navigatingFrom) }
                announce(.disappearing)
                if reason == .navigation { announce(.navigatedFrom) }
            }

        case .navigationStack:
            children.last?.setPagePresented(
                presented,
                reason: reason == .window && presented ? .navigation
                    : (reason == .window ? .appearance : reason))

        case .tabbedView:
            selectedTab?.setPagePresented(presented, reason: .appearance)

        case .splitView:
            children.dropFirst().first?.setPagePresented(presented, reason: .appearance)
            if sidebarIsVisible {
                children.first?.setPagePresented(presented, reason: .appearance)
            }

        default:
            break
        }
    }

    private func announce(_ event: Event) {
        guard let handler = events[event] else { return }
        host?.enqueue(handler, isPhase: true)
    }

    /// What this arrangement shows while it is shown itself: a stack's top
    /// page, a tabbed view's selected tab, a split view's detail and - while
    /// it shows - its sidebar. Nothing, for anything else.
    private var shownChildren: [MountedNode] {
        switch type {
        case .navigationStack:
            return children.last.map { [$0] } ?? []
        case .tabbedView:
            return selectedTab.map { [$0] } ?? []
        case .splitView:
            let detail = Array(children.dropFirst().prefix(1))
            return sidebarIsVisible ? detail + children.prefix(1) : detail
        default:
            return []
        }
    }

    /// Moves presentation to follow a change of the arrangement - a push or a
    /// pop, another tab, the sidebar showing or hiding, or a shown child
    /// replaced outright: what stopped showing leaves first, then what started
    /// showing arrives. On a stack that is a navigation; anywhere else it is a
    /// change of what is visible.
    private func reconcilePresentation(from previous: [MountedNode]) {
        guard pagePresented else { return }
        let current = shownChildren
        let reason: AppKitPagePresentationReason =
            type == .navigationStack ? .navigation : .appearance

        for child in previous where !current.contains(where: { $0 === child }) {
            child.setPagePresented(false, reason: reason)
        }
        for child in current where !previous.contains(where: { $0 === child }) {
            child.setPagePresented(true, reason: reason)
        }
    }

    /// Reports the tab a tabbed view fell back to when its selected tab went
    /// away.
    private func reportTabFallback() {
        if let fallback = pendingTabFallback,
           let handler = events[.currentPageChanged] {
            host?.enqueue(handler, payload: [.number(Double(fallback))])
        }
        pendingTabFallback = nil
    }

    private var selectedTab: MountedNode? {
        guard !children.isEmpty else { return nil }
        let requested = (view as? AppKitTabbedView)?.selectedIndex ?? whole(.currentPage) ?? 0
        return children[min(max(requested, 0), children.count - 1)]
    }

    private var sidebarIsVisible: Bool {
        if let split = view as? AppKitSplitView {
            return split.isEffectivelyPresented
        }
        return value(.isSidebarVisible)?.bool == true
    }

    func takeCreatedHandlers() -> [Int32] {
        var handlers: [Int32] = []

        if !created {
            created = true
            if type != .window, let handler = events[.created] {
                handlers.append(handler)
            }
        }

        for child in children {
            handlers.append(contentsOf: child.takeCreatedHandlers())
        }

        return handlers
    }

    func string(_ property: Prop) -> String? {
        value(property)?.string
    }

    func name(_ property: Prop) -> String? {
        value(property)?.name
    }

    func number(_ property: Prop) -> Double? {
        value(property)?.number
    }

    func bool(_ property: Prop) -> Bool? {
        value(property)?.bool
    }

    func handler(_ event: Event) -> Int32? {
        events[event]
    }

    @discardableResult
    func applyState(_ state: Int32, value: HostStateValue) -> AppKitPresentationImpact {
        applyStates([state: value])
    }

    @discardableResult
    func applyStates(
        _ valuesByState: [Int32: HostStateValue]
    ) -> AppKitPresentationImpact {
        applyFrame(states: valuesByState, properties: [:])
    }

    /// Properties a parent reads into its child's layout item. A frame that
    /// moves one of them makes the parent arrange again; no other frame
    /// arranges an ancestor.
    private static let arrangedProperties: Set<Prop> = [
        .margin, .horizontalAlignment, .verticalAlignment,
        .width, .height,
        .minimumWidth, .minimumHeight,
        .maximumWidth, .maximumHeight,
        .gridRow, .gridColumn, .gridRowSpan, .gridColumnSpan,
        .absoluteLayoutBounds, .absoluteLayoutProportions,
    ]

    /// Properties whose change is drawn without changing any native
    /// measurement. Applying any other property may change a view's size, so
    /// it forgets the measurements from that view up to its window.
    private static let unmeasuredProperties: Set<Prop> = [
        .opacity, .translationX, .translationY,
        .rotation, .rotationX, .rotationY, .scale, .scaleX, .scaleY,
        .pivotX, .pivotY,
        .background, .color, .textColor, .placeholderColor,
        .tint, .borderColor, .stroke, .fill, .strokeWidth,
        .strokeDashPattern, .strokeDashOffset, .strokeLineCap, .strokeLineJoin,
        .strokeMiterLimit, .shape, .cornerRadius, .renderTransform,
        .barBackgroundColor, .barForegroundColor,
        .drawable, .value, .progress, .scrollOffset, .isOn, .isEnabled,
        .ignoresInput, .letsInputThrough,
        .accessibilityIdentifier, .isAccessibilityHidden, .automationExcludedWithChildren,
        .accessibilityLabel, .accessibilityHint, .accessibilityHeadingLevel,
    ]

    /// Only properties whose native presentation lives outside the mounted
    /// content view need the scene/window reconciliation path. Ordinary view
    /// frames are already applied in place and AppKit lays them out before the
    /// display link's frame is drawn.
    private func needsWindowSynchronization(for properties: Set<Prop>) -> Bool {
        guard !properties.isEmpty else { return false }
        return type == .window || type == .titleBar || type == .navigationStack
    }

    @objc private func clicked(_ sender: Any?) {
        guard let handler = events[.clicked] else { return }
        host?.dispatch(handler)
    }

    private func typed(_ text: String) {
        guard let host else { return }

        let reported = driven[.text].map { host.report(.text(text), through: $0) } ?? false

        if let handler = events[.textChanged] {
            host.dispatch(handler, payload: [.string(text)])
        } else if reported {
            host.pump()
        }
    }

    private func submitted() {
        guard let handler = events[.submitted] else { return }
        host?.dispatch(handler)
    }

    private func pressed() {
        guard let handler = events[.pressed] else { return }
        host?.dispatch(handler)
    }

    private func released() {
        guard let handler = events[.released] else { return }
        host?.dispatch(handler)
    }

    private func changedNumericValue(to value: Double) {
        guard let host else { return }

        let reported = driven[.value].map { host.take([value], through: $0) } ?? false

        if let handler = events[.valueChanged] {
            host.dispatch(handler, payload: [.number(value)])
        } else if reported {
            host.pump()
        }
    }

    private func changedBoolean(_ value: Bool, property: Prop, event: Event) {
        guard let host else { return }

        let reported = driven[property].map {
            host.report(.lanes([value ? 1 : 0]), through: $0)
        } ?? false

        if let handler = events[event] {
            host.dispatch(handler, payload: [.bool(value)])
        } else if reported {
            host.settleReaderWrite(true)
        }
    }

    private func selectedRadio() {
        guard type == .radioButton, let host else { return }

        let group = name(.groupName).flatMap { $0.isEmpty ? nil : $0 }
        let scope = radioScope(named: group)
        let peers = group.map { scope.radioButtons(named: $0) }
            ?? (parent?.children.filter { $0.type == .radioButton } ?? [self])
        let formerlySelected = peers.filter { $0 !== self && $0.bool(.isOn) == true }
        let alreadySelected = bool(.isOn) == true

        guard !formerlySelected.isEmpty || !alreadySelected else { return }

        host.performReaderTransaction {
            for peer in formerlySelected {
                peer.setRadioChecked(false)
                peer.changedBoolean(false, property: .isOn, event: .toggled)
            }

            if !alreadySelected {
                setRadioChecked(true)
                changedBoolean(true, property: .isOn, event: .toggled)
            }
        }
    }

    private func changedSelection(to index: Int) {
        guard let host else { return }

        let reported = driven[.selectedIndex].map {
            host.report(.lanes([Double(index)]), through: $0)
        } ?? false

        if let handler = events[.selectedIndexChanged] {
            host.dispatch(handler, payload: [.number(Double(index))])
        } else if reported {
            host.pump()
        }
    }

    private func changedLanes(_ lanes: [Double], property: Prop, event: Event) {
        guard let host else { return }

        let reported = driven[property].map {
            host.report(.lanes(lanes), through: $0)
        } ?? false

        if let handler = events[event] {
            host.dispatch(handler, payload: [.numbers(lanes)])
        } else if reported {
            host.pump()
        }
    }

    private func pickerOpened() {
        guard let handler = events[.opened] else { return }
        host?.dispatch(handler)
    }

    private func pickerClosed() {
        guard let handler = events[.closed] else { return }
        host?.dispatch(handler)
    }

    private func beganSliderDrag() {
        guard let handler = events[.dragStarted] else { return }
        host?.dispatch(handler)
    }

    private func completedSliderDrag() {
        guard let handler = events[.dragCompleted] else { return }
        host?.dispatch(handler)
    }

    private func tapped() {
        guard let handler = events[.tapped] else { return }
        host?.dispatch(handler)
    }

    private func swiped(_ direction: Int32) {
        guard let handler = events[.swiped] else { return }
        host?.dispatch(handler, payload: [.enumeration(direction)])
    }

    private func panChanged(_ phase: AppKitGesturePhase, total: NSPoint) {
        guard let host else { return }
        let across = whole(.panXChannel).flatMap { $0 == 0 ? nil : Int32($0) }
        let down = whole(.panYChannel).flatMap { $0 == 0 ? nil : Int32($0) }

        if phase == .started {
            panFromX = across.flatMap(host.standingGestureValue(state:)) ?? 0
            panFromY = down.flatMap(host.standingGestureValue(state:)) ?? 0
        }

        var changedState = false
        host.performReaderTransaction {
            if phase == .running {
                if let across {
                    changedState = host.takeGestureValue(
                        panFromX + Double(total.x), state: across) || changedState
                }
                if let down {
                    changedState = host.takeGestureValue(
                        panFromY + Double(total.y), state: down) || changedState
                }
            }

            if let handler = events[.panUpdated] {
                host.dispatch(handler, payload: [
                    .enumeration(phase.rawValue),
                    .number(Double(total.x)),
                    .number(Double(total.y)),
                ])
            }
        }
        host.settleReaderWrite(changedState)
    }

    private func pinchChanged(
        _ phase: AppKitGesturePhase,
        scale: CGFloat,
        origin: NSPoint
    ) {
        guard let handler = events[.pinchUpdated] else { return }
        host?.dispatch(handler, payload: [
            .enumeration(phase.rawValue),
            .number(Double(scale)),
            .numbers([Double(origin.x), Double(origin.y)]),
        ])
    }

    private func pointerChanged(
        _ report: AppKitPointerRecognizer.Report,
        point: NSPoint?
    ) {
        let event: Event = switch report {
        case .entered: .pointerEntered
        case .exited: .pointerExited
        case .moved: .pointerMoved
        case .pressed: .pointerPressed
        case .released: .pointerReleased
        }
        guard let handler = events[event] else { return }
        let payload: [HostValue] = point.map {
            [.numbers([Double($0.x), Double($0.y)])]
        } ?? []
        host?.dispatch(handler, payload: payload)
    }

    private func canvasPointer(_ event: Event, at point: NSPoint) {
        guard let handler = events[event] else { return }
        host?.dispatch(handler, payload: [.numbers([Double(point.x), Double(point.y)])])
    }

    private func scrolled(from old: NSPoint, to new: NSPoint) {
        guard let host else { return }
        var tookState = false
        host.performReaderTransaction {
            if old != new, let binding = driven[.scrollOffset] {
                tookState = host.take([Double(new.x), Double(new.y)], through: binding)
            }

            if old.x != new.x, let handler = events[.scrollXChanged] {
                host.dispatch(handler, payload: [.number(Double(new.x))])
            }
            if old.y != new.y, let handler = events[.scrollYChanged] {
                host.dispatch(handler, payload: [.number(Double(new.y))])
            }
        }
        host.settleReaderWrite(tookState)
    }

    private func scrollStopped() {
        guard let handler = events[.scrollStopped] else { return }
        host?.dispatch(handler)
    }

    private func makeView() -> NSView? {
        switch type {
        case .application, .scene, .window:
            return nil

        case .page:
            let page = AppKitSingleChildView()
            page.translatesAutoresizingMaskIntoConstraints = true
            return page

        case .modalStack, .titleBar, .content, .leadingContent, .trailingContent,
             .titleView, .toolbarItems, .menuBar, .contextMenu,
             .menu, .menuItem,
             .menuSeparator, .spans, .span:
            return nil

        case .navigationStack:
            return AppKitNavigationView()

        case .tabbedView:
            return AppKitTabbedView()

        case .splitView:
            return AppKitSplitView()

        case .grid:
            return AppKitGridView()

        case .absoluteLayout:
            return AppKitAbsoluteLayoutView()

        case .border:
            return AppKitBorderView()

        case .vStack:
            return AppKitStackView(axis: .vertical)

        case .hStack:
            return AppKitStackView(axis: .horizontal)

        case .scrollView:
            let scroll = AppKitScrollView()
            scroll.onOffsetChanged = { [weak self] old, new in
                self?.scrolled(from: old, to: new)
            }
            scroll.onScrollStopped = { [weak self] in self?.scrollStopped() }
            scroll.onFramesWanted = { [weak self, weak scroll] in
                guard let scroll else { return }
                self?.host?.requestFrames(for: scroll)
            }
            return scroll

        case .label:
            return AppKitLabelView()

        case .button:
            let button = AppKitButtonView()
            button.onClicked = { [weak self] in self?.clicked(nil) }
            button.onPressed = { [weak self] in self?.pressed() }
            button.onReleased = { [weak self] in self?.released() }
            return button

        case .toolbarItem:
            // The window's toolbar makes the native item; see visibleToolbarActions.
            return nil

        case .textField:
            let entry = AppKitTextFieldView()
            entry.onTextChanged = { [weak self] in self?.typed($0) }
            entry.onSubmitted = { [weak self] in self?.submitted() }
            return entry

        case .textEditor:
            let editor = AppKitTextEditorView()
            editor.onTextChanged = { [weak self] in self?.typed($0) }
            return editor

        case .searchField:
            let search = AppKitSearchFieldView()
            search.onTextChanged = { [weak self] in self?.typed($0) }
            search.onSubmitted = { [weak self] in self?.submitted() }
            return search

        case .slider:
            let slider = AppKitSliderView()
            slider.onValueChanged = { [weak self] in self?.changedNumericValue(to: $0) }
            slider.onDragStarted = { [weak self] in self?.beganSliderDrag() }
            slider.onDragCompleted = { [weak self] in self?.completedSliderDrag() }
            return slider

        case .progressBar:
            return AppKitProgressView()

        case .activityIndicator:
            return AppKitActivityIndicatorView()

        case .switch:
            let toggle = AppKitSwitchView()
            toggle.onToggled = { [weak self] in
                self?.changedBoolean($0, property: .isOn, event: .toggled)
            }
            return toggle

        case .checkBox:
            let checkBox = AppKitCheckBoxView()
            checkBox.onToggled = { [weak self] in
                self?.changedBoolean($0, property: .isOn, event: .toggled)
            }
            return checkBox

        case .radioButton:
            let radio = AppKitRadioButtonView()
            radio.onSelected = { [weak self] in self?.selectedRadio() }
            return radio

        case .stepper:
            let stepper = AppKitStepperView()
            stepper.onValueChanged = { [weak self] in self?.changedNumericValue(to: $0) }
            return stepper

        case .picker:
            let picker = AppKitPickerView()
            picker.onSelectionChanged = { [weak self] in self?.changedSelection(to: $0) }
            picker.onOpened = { [weak self] in self?.pickerOpened() }
            picker.onClosed = { [weak self] in self?.pickerClosed() }
            return picker

        case .datePicker:
            let picker = AppKitDateTimePickerView(mode: .date)
            picker.onValueChanged = { [weak self] in
                self?.changedLanes($0, property: .date, event: .dateChanged)
            }
            return picker

        case .timePicker:
            let picker = AppKitDateTimePickerView(mode: .time)
            picker.onValueChanged = { [weak self] in
                self?.changedLanes($0, property: .time, event: .timeChanged)
            }
            return picker

        case .colorBox:
            return AppKitColorBoxView()

        case .image:
            return AppKitImageView()

        case .canvas:
            let canvas = AppKitCanvasView()
            canvas.onPressed = { [weak self] point in
                self?.canvasPointer(.pressed, at: point)
            }
            canvas.onDragged = { [weak self] point in
                self?.canvasPointer(.dragged, at: point)
            }
            canvas.onReleased = { [weak self] point in
                self?.canvasPointer(.released, at: point)
            }
            return canvas

        case .rectangle:
            return AppKitShapeView(kind: .rectangle)


        case .ellipse:
            return AppKitShapeView(kind: .ellipse)

        case .line:
            return AppKitShapeView(kind: .line)

        case .path:
            return AppKitShapeView(kind: .path)

        case .polygon:
            return AppKitShapeView(kind: .polygon)

        case .polyline:
            return AppKitShapeView(kind: .polyline)

        default:
            return AppKitUnsupportedView(type)
        }
    }

    /// The layout's own placement run, where a state drives one: the room's
    /// arithmetic over the children, which moves them without changing what
    /// the layout measures - a run is not part of its natural size.
    private var ownPlacementRun: Set<Prop> {
        driven[.absoluteLayoutBounds]?.kind == .placement ? [.absoluteLayoutBounds] : []
    }

    private func applyProperties(changed: Set<Prop>) {
        guard let view else { return }

        if !changed.subtracting(ownPlacementRun).isSubset(of: Self.unmeasuredProperties) {
            view.invalidateMeasurements()
        }

        view.isHidden = value(.isVisible)?.bool == false
        view.alphaValue = value(.opacity)?.number ?? 1
        if let hitTestView = view as? AppKitHitTestView {
            // The whole view and its children, or only its own empty area.
            let ignores = value(.ignoresInput)?.bool ?? false
            hitTestView.applyInputTransparency(
                ignores || value(.letsInputThrough)?.bool == true,
                cascades: ignores)
        }
        if !(view is AppKitBorderView) && !(view is AppKitColorBoxView) {
            let background = color(.background)
            view.wantsLayer = true
            view.layer?.backgroundColor = background?.cgColor
        }

        if type == .toolbarItem, let button = view as? NSButton {
            button.title = string(.text) ?? ""
            let buttonFont = font(fallback: NSFont.systemFont(ofSize: NSFont.systemFontSize))
            button.font = buttonFont
            button.isEnabled = value(.isEnabled)?.bool ?? true

            let foreground = value(.isDestructive)?.bool == true
                ? NSColor.systemRed
                : (color(.textColor) ?? .controlTextColor)
            button.attributedTitle = NSAttributedString(
                string: button.title,
                attributes: [.font: buttonFont, .foregroundColor: foreground])

            button.image = string(.icon).flatMap { image(named: $0) }
            button.imagePosition = button.image == nil
                ? .noImage
                : (button.title.isEmpty ? .imageOnly : .imageLeading)

            let background = color(.background)
            button.isBordered = background == nil
            button.wantsLayer = background != nil
            button.layer?.backgroundColor = background?.cgColor
            button.layer?.cornerRadius = value(.cornerRadius)?.number ?? 0
        }

        if let button = view as? AppKitButtonView {
            let caption = string(.text) ?? ""
            let foreground = value(.isDestructive)?.bool == true
                ? NSColor.systemRed
                : (color(.textColor) ?? .controlTextColor)
            button.apply(
                text: caption,
                image: string(.icon).flatMap { image(named: $0) },
                imagePosition: buttonImagePosition(imageOnly: caption.isEmpty),
                imageScaling: imageScaling(enumeration(.aspect)),
                font: font(fallback: NSFont.systemFont(ofSize: NSFont.systemFontSize)),
                textColor: foreground,
                backgroundColor: color(.background),
                borderColor: color(.borderColor),
                borderWidth: value(.borderWidth)?.number ?? 0,
                cornerRadius: value(.cornerRadius)?.number ?? 0,
                lineBreakMode: lineBreakMode(enumeration(.lineBreak)),
                enabled: value(.isEnabled)?.bool ?? true)
        }

        if let stack = view as? AppKitStackView {
            stack.spacing = value(.spacing)?.number ?? 0
            stack.padding = insets(.padding)
        }

        if let page = view as? AppKitSingleChildView {
            page.padding = insets(.padding)
        }

        if let split = view as? AppKitSplitView {
            split.onPresentationChanged = { [weak self] presented in
                self?.changeSidebarVisibility(to: presented)
            }
            split.apply(presented: value(.isSidebarVisible)?.bool ?? false)
        }

        if let grid = view as? AppKitGridView {
            grid.rows = gridLengths(.rows)
            grid.columns = gridLengths(.columns)
            grid.rowSpacing = value(.rowSpacing)?.number ?? 0
            grid.columnSpacing = value(.columnSpacing)?.number ?? 0
            grid.padding = insets(.padding)
        }

        if let absolute = view as? AppKitAbsoluteLayoutView {
            absolute.placement = placement(.absoluteLayoutBounds)
        }

        if let scroll = view as? AppKitScrollView {
            let offset = changed.contains(.scrollOffset)
                ? value(.scrollOffset)?.numbers.flatMap { values -> NSPoint? in
                    guard values.count >= 2 else { return nil }
                    return NSPoint(x: values[0], y: values[1])
                }
                : nil
            scroll.apply(
                orientation: enumeration(.orientation) ?? ScrollOrientation.vertical.rawValue,
                padding: insets(.padding),
                verticalBarVisibility: enumeration(.verticalScrollBarVisibility) ?? 0,
                horizontalBarVisibility: enumeration(.horizontalScrollBarVisibility) ?? 0,
                offset: offset)
        }

        if let imageView = view as? AppKitImageView {
            imageView.apply(
                image: string(.source).flatMap { image(named: $0) },
                aspect: imageAspect(enumeration(.aspect)),
                animationPlaying: value(.isAnimating)?.bool ?? false)
        }

        if let entry = view as? AppKitTextFieldView {
            let attachedText = attachedTextValue()

            entry.apply(
                text: attachedText,
                writeText: changed.contains(.text) && attachedText != nil,
                placeholder: string(.placeholder),
                placeholderColor: color(.placeholderColor),
                foregroundColor: color(.textColor) ?? .controlTextColor,
                backgroundColor: color(.background),
                font: font(fallback: NSFont.systemFont(ofSize: NSFont.systemFontSize)),
                horizontalAlignment: enumeration(.horizontalTextAlignment),
                enabled: value(.isEnabled)?.bool ?? true,
                readOnly: value(.isReadOnly)?.bool ?? false,
                secure: value(.isPassword)?.bool ?? false,
                maximumLength: whole(.maximumLength),
                spellChecking: value(.isSpellCheckEnabled)?.bool ?? true,
                textPrediction: value(.isTextPredictionEnabled)?.bool ?? true,
                cursorPosition: whole(.cursorPosition),
                selectionLength: whole(.selectionLength),
                writeSelection: changed.contains(.cursorPosition)
                    || changed.contains(.selectionLength))
        }

        if let editor = view as? AppKitTextEditorView {
            let attachedText = attachedTextValue()

            editor.apply(
                text: attachedText,
                writeText: changed.contains(.text) && attachedText != nil,
                placeholder: string(.placeholder),
                placeholderColor: color(.placeholderColor),
                foregroundColor: color(.textColor) ?? .controlTextColor,
                backgroundColor: color(.background),
                font: font(fallback: NSFont.systemFont(ofSize: NSFont.systemFontSize)),
                horizontalAlignment: enumeration(.horizontalTextAlignment),
                enabled: value(.isEnabled)?.bool ?? true,
                readOnly: value(.isReadOnly)?.bool ?? false,
                maximumLength: whole(.maximumLength),
                spellChecking: value(.isSpellCheckEnabled)?.bool ?? true,
                textPrediction: value(.isTextPredictionEnabled)?.bool ?? true,
                cursorPosition: whole(.cursorPosition),
                selectionLength: whole(.selectionLength),
                writeSelection: changed.contains(.cursorPosition)
                    || changed.contains(.selectionLength),
                growsWithText: value(.growsWithText)?.bool == true)
        }

        if let search = view as? AppKitSearchFieldView {
            let attachedText = attachedTextValue()

            search.apply(
                text: attachedText,
                writeText: changed.contains(.text) && attachedText != nil,
                placeholder: string(.placeholder),
                placeholderColor: color(.placeholderColor),
                foregroundColor: color(.textColor) ?? .controlTextColor,
                backgroundColor: color(.background),
                font: font(fallback: NSFont.systemFont(ofSize: NSFont.systemFontSize)),
                horizontalAlignment: enumeration(.horizontalTextAlignment),
                enabled: value(.isEnabled)?.bool ?? true,
                readOnly: value(.isReadOnly)?.bool ?? false,
                maximumLength: whole(.maximumLength),
                spellChecking: value(.isSpellCheckEnabled)?.bool ?? true,
                textPrediction: value(.isTextPredictionEnabled)?.bool ?? true,
                cursorPosition: whole(.cursorPosition),
                selectionLength: whole(.selectionLength),
                writeSelection: changed.contains(.cursorPosition)
                    || changed.contains(.selectionLength))
        }

        if let slider = view as? AppKitSliderView {
            let attachedValue: Double?

            if driven[.value] != nil {
                attachedValue = value(.value)?.number
            } else {
                attachedValue = number(.value) ?? 0
            }

            slider.apply(
                value: attachedValue,
                writeValue: changed.contains(.value) && attachedValue != nil,
                minimum: number(.minimum) ?? 0,
                maximum: number(.maximum) ?? 1,
                tint: color(.tint),
                enabled: value(.isEnabled)?.bool ?? true)
        }

        if let progress = view as? AppKitProgressView {
            progress.apply(progress: value(.progress)?.number ?? 0)
        }
        if let activity = view as? AppKitActivityIndicatorView {
            activity.apply(running: value(.isRunning)?.bool ?? false)
        }
        if let toggle = view as? AppKitSwitchView {
            toggle.apply(
                toggled: value(.isOn)?.bool ?? false,
                enabled: value(.isEnabled)?.bool ?? true)
        }
        if let checkBox = view as? AppKitCheckBoxView {
            checkBox.apply(
                checked: value(.isOn)?.bool ?? false,
                enabled: value(.isEnabled)?.bool ?? true,
                tint: color(.tint))
        }
        if let radio = view as? AppKitRadioButtonView {
            radio.apply(
                checked: value(.isOn)?.bool ?? false,
                text: transformed(
                    string(.text) ?? "",
                    by: enumeration(.textCase)),
                font: font(fallback: NSFont.systemFont(ofSize: NSFont.systemFontSize)),
                textColor: color(.textColor) ?? .controlTextColor,
                enabled: value(.isEnabled)?.bool ?? true)
        }
        if let stepper = view as? AppKitStepperView {
            stepper.apply(
                value: value(.value)?.number,
                writeValue: changed.contains(.value),
                minimum: value(.minimum)?.number ?? 0,
                maximum: value(.maximum)?.number ?? 100,
                step: value(.step)?.number ?? 1,
                enabled: value(.isEnabled)?.bool ?? true)
        }
        if let picker = view as? AppKitPickerView {
            picker.apply(
                items: value(.options)?.strings ?? [],
                selectedIndex: whole(.selectedIndex) ?? -1,
                writeSelection: changed.contains(.selectedIndex),
                title: string(.title),
                font: font(fallback: NSFont.systemFont(ofSize: NSFont.systemFontSize)),
                textColor: color(.textColor) ?? .controlTextColor,
                tint: color(.tint),
                alignment: textAlignment(enumeration(.horizontalTextAlignment)),
                enabled: value(.isEnabled)?.bool ?? true,
                open: value(.isOpen)?.bool ?? false,
                writeOpen: changed.contains(.isOpen))
        }
        if type == .datePicker, let picker = view as? AppKitDateTimePickerView {
            picker.apply(
                value: value(.date)?.numbers,
                writeValue: changed.contains(.date),
                minimum: value(.minimumDate)?.numbers,
                maximum: value(.maximumDate)?.numbers,
                font: font(fallback: NSFont.systemFont(ofSize: NSFont.systemFontSize)),
                textColor: color(.textColor) ?? .controlTextColor,
                enabled: value(.isEnabled)?.bool ?? true)
        }
        if type == .timePicker, let picker = view as? AppKitDateTimePickerView {
            picker.apply(
                value: value(.time)?.numbers,
                writeValue: changed.contains(.time),
                minimum: nil,
                maximum: nil,
                font: font(fallback: NSFont.systemFont(ofSize: NSFont.systemFontSize)),
                textColor: color(.textColor) ?? .controlTextColor,
                enabled: value(.isEnabled)?.bool ?? true)
        }

        if let box = view as? AppKitColorBoxView {
            box.apply(
                background: color(.background),
                fill: color(.color),
                cornerRadius: value(.cornerRadius))
        }

        if let border = view as? AppKitBorderView {
            border.apply(
                backgroundColor: color(.background),
                background: value(.background),
                stroke: value(.stroke),
                strokeWidth: value(.strokeWidth)?.number,
                shape: value(.shape))
        }

        if let shape = view as? AppKitShapeView {
            let geometry: AppKitShapeGeometry = switch type {
            case .rectangle:
                .rectangle(AppKitCornerRadii(value(.cornerRadius)))
            case .ellipse:
                .ellipse
            case .line:
                .line(
                    x1: number(.x1).map { CGFloat($0) } ?? 0,
                    y1: number(.y1).map { CGFloat($0) } ?? 0,
                    x2: number(.x2).map { CGFloat($0) } ?? 0,
                    y2: number(.y2).map { CGFloat($0) } ?? 0)
            case .path:
                .path(string(.data) ?? "")
            case .polygon, .polyline:
                .points(
                    value(.points)?.numbers ?? [],
                    fillRule: enumeration(.fillRule) ?? 0)
            default:
                .points([], fillRule: 0)
            }
            shape.apply(
                fill: value(.fill),
                stroke: value(.stroke),
                strokeWidth: number(.strokeWidth) ?? 1,
                dash: value(.strokeDashPattern)?.numbers ?? [],
                dashOffset: number(.strokeDashOffset) ?? 0,
                lineCap: enumeration(.strokeLineCap) ?? 0,
                lineJoin: enumeration(.strokeLineJoin) ?? 0,
                miterLimit: number(.strokeMiterLimit) ?? 10,
                aspect: enumeration(.aspect) ?? 0,
                renderTransform: transformComponents(.renderTransform),
                geometry: geometry)
        }

        if let canvas = view as? AppKitCanvasView {
            canvas.apply(value(.drawable))
        }

        let minimumWidth = requested(.minimumWidth)
        let minimumHeight = requested(.minimumHeight)
        let maximumWidth = requested(.maximumWidth).map { max($0, minimumWidth ?? 0) }
        let maximumHeight = requested(.maximumHeight).map { max($0, minimumHeight ?? 0) }
        widthConstraint = reconciledConstraint(
            widthConstraint,
            value: requested(.width).map {
                appKitBoundedExtent($0, minimum: minimumWidth, maximum: maximumWidth)
            },
            make: { view.widthAnchor.constraint(equalToConstant: $0) })
        heightConstraint = reconciledConstraint(
            heightConstraint,
            value: requested(.height).map {
                appKitBoundedExtent($0, minimum: minimumHeight, maximum: maximumHeight)
            },
            make: { view.heightAnchor.constraint(equalToConstant: $0) })
        minimumWidthConstraint = reconciledConstraint(
            minimumWidthConstraint,
            value: minimumWidth,
            make: { view.widthAnchor.constraint(greaterThanOrEqualToConstant: $0) })
        minimumHeightConstraint = reconciledConstraint(
            minimumHeightConstraint,
            value: minimumHeight,
            make: { view.heightAnchor.constraint(greaterThanOrEqualToConstant: $0) })
        maximumWidthConstraint = reconciledConstraint(
            maximumWidthConstraint,
            value: maximumWidth,
            make: { view.widthAnchor.constraint(lessThanOrEqualToConstant: $0) })
        maximumHeightConstraint = reconciledConstraint(
            maximumHeightConstraint,
            value: maximumHeight,
            make: { view.heightAnchor.constraint(lessThanOrEqualToConstant: $0) })

        if let button = view as? NSButton,
           let padding = value(.padding)?.numbers, padding.count >= 4 {
            let intrinsic = button.intrinsicContentSize
            buttonWidthConstraint = reconciledConstraint(
                buttonWidthConstraint,
                value: intrinsic.width + padding[0] + padding[2],
                make: {
                    let constraint = button.widthAnchor.constraint(
                        greaterThanOrEqualToConstant: $0)
                    constraint.priority = .defaultHigh
                    return constraint
                })
            buttonHeightConstraint = reconciledConstraint(
                buttonHeightConstraint,
                value: intrinsic.height + padding[1] + padding[3],
                make: {
                    let constraint = button.heightAnchor.constraint(
                        greaterThanOrEqualToConstant: $0)
                    constraint.priority = .defaultHigh
                    return constraint
                })
        } else {
            buttonWidthConstraint?.isActive = false
            buttonWidthConstraint = nil
            buttonHeightConstraint?.isActive = false
            buttonHeightConstraint = nil
        }

        drawing?.own = drawingTransform()
        // Last, so the words meet the control as configured above - a text
        // field may just have swapped in a password field.
        applyAccessibility(to: view)
    }

    /// The view's own drawing transform. `scale` multiplies both axes on
    /// top of `scaleX` and `scaleY`.
    private func drawingTransform() -> HostDrawingTransform {
        let scale = value(.scale)?.number ?? 1
        return HostDrawingTransform(
            translationX: value(.translationX)?.number ?? 0,
            translationY: value(.translationY)?.number ?? 0,
            rotation: value(.rotation)?.number ?? 0,
            rotationX: value(.rotationX)?.number ?? 0,
            rotationY: value(.rotationY)?.number ?? 0,
            scaleX: scale * (value(.scaleX)?.number ?? 1),
            scaleY: scale * (value(.scaleY)?.number ?? 1),
            pivotX: value(.pivotX)?.number ?? 0.5,
            pivotY: value(.pivotY)?.number ?? 0.5)
    }

    /// Keeps the native constraint identity stable while a host channel moves
    /// its constant. Creating and tearing down the Auto Layout graph on every
    /// display frame is both unnecessary work and visible as uneven motion.
    private func reconciledConstraint(
        _ existing: NSLayoutConstraint?,
        value: CGFloat?,
        make: (CGFloat) -> NSLayoutConstraint
    ) -> NSLayoutConstraint? {
        guard let value else {
            existing?.isActive = false
            return nil
        }

        if let existing {
            existing.constant = value
            return existing
        }

        let constraint = make(value)
        constraint.isActive = true
        return constraint
    }

    private func arrangeChildren() {
        guard let view else { return }
        let items = children.compactMap(\.layoutItem)

        if let label = view as? AppKitLabelView {
            label.apply(
                attributedText: attributedLabelText(),
                padding: insets(.padding),
                horizontalAlignment: textAlignment(enumeration(.horizontalTextAlignment)),
                verticalAlignment: AppKitVerticalTextAlignment(
                    rawValue: enumeration(.verticalTextAlignment) ?? 0) ?? .start,
                lineBreakMode: lineBreakMode(enumeration(.lineBreak)),
                maximumNumberOfLines: effectiveMaximumLines())
            return
        }

        if let stack = view as? AppKitStackView {
            stack.setItems(items)
            return
        }

        if let split = view as? AppKitSplitView {
            split.setItems(items)
            return
        }

        if let navigation = view as? AppKitNavigationView {
            navigation.setItems(items)
            return
        }

        if let tabs = view as? AppKitTabbedView {
            let tabItems = children.compactMap { child -> AppKitTabItem? in
                guard let layout = child.layoutItem else { return nil }
                return AppKitTabItem(
                    layout: layout,
                    title: child.string(.title),
                    image: child.string(.icon).flatMap { image(named: $0) })
            }
            tabs.onSelection = { [weak self] previous, selected in
                self?.selectTab(from: previous, to: selected)
            }
            pendingTabFallback = tabs.setItems(
                tabItems,
                requestedIndex: whole(.currentPage))
            return
        }

        if let page = view as? AppKitSingleChildView {
            page.setItem(items.first)
            return
        }

        if let grid = view as? AppKitGridView {
            grid.setItems(items)
            return
        }

        if let absolute = view as? AppKitAbsoluteLayoutView {
            absolute.setItems(
                items,
                retaining: recycledChildren.compactMap(\.layoutItem),
                preservesSubviewOrder: recycles)
            return
        }

        if let scroll = view as? AppKitScrollView {
            scroll.setItems(items)
        }
    }

    private var layoutItem: AppKitLayoutItem? {
        guard let view = presentableViews.first else { return nil }
        var item = AppKitLayoutItem(view: view)
        item.margin = insets(.margin)
        item.horizontal = enumeration(.horizontalAlignment) ?? 3
        item.vertical = enumeration(.verticalAlignment) ?? 3
        item.width = requested(.width)
        item.height = requested(.height)
        item.minimumWidth = requested(.minimumWidth)
        item.minimumHeight = requested(.minimumHeight)
        item.maximumWidth = requested(.maximumWidth)
        item.maximumHeight = requested(.maximumHeight)
        item.row = whole(.gridRow) ?? 0
        item.column = whole(.gridColumn) ?? 0
        item.rowSpan = max(whole(.gridRowSpan) ?? 1, 1)
        item.columnSpan = max(whole(.gridColumnSpan) ?? 1, 1)
        item.absoluteBounds = value(.absoluteLayoutBounds)?.numbers
        item.absoluteProportions = enumeration(.absoluteLayoutProportions) ?? 0
        item.drawing = presentableDrawing
        return item
    }

    /// The drawing of the view `presentableViews` puts first.
    private var presentableDrawing: AppKitViewDrawing? {
        if view != nil { return drawing }
        return children.lazy.compactMap(\.presentableDrawing).first
    }

    /// Applies StateUI's semantic surface without replacing the native
    /// control's ordinary role or participation when the author says nothing.
    private func applyAccessibility(to view: NSView) {
        let target = accessibilityTarget(of: view)
        if accessibilityDefaults == nil {
            accessibilityDefaults = (
                isElement: target.isAccessibilityElement(),
                role: target.accessibilityRole())
        }
        guard let defaults = accessibilityDefaults else { return }

        target.setAccessibilityIdentifier(string(.accessibilityIdentifier))
        target.setAccessibilityLabel(string(.accessibilityLabel))
        target.setAccessibilityHelp(string(.accessibilityHint))

        let excludesChildren = value(.automationExcludedWithChildren)?.bool == true
        if excludesChildren {
            view.setAccessibilityChildren([])
            accessibilityChildrenSuppressed = true
        } else if accessibilityChildrenSuppressed {
            view.setAccessibilityChildren(nil)
            accessibilityChildrenSuppressed = false
        }

        let headingLevel = max(0, enumeration(.accessibilityHeadingLevel) ?? 0)
        let carriesSemantics = string(.accessibilityLabel) != nil
            || string(.accessibilityHint) != nil
            || headingLevel > 0
        // An element that answers a tap is a button to assistive technology,
        // pressed by the handler a click runs. See `AppKitHitTestView`.
        let pressable = events[.tapped] != nil && view is AppKitHitTestView
        // The author says whether the view is hidden; an element is the opposite.
        let authoredElement = value(.isAccessibilityHidden)?.bool.map { !$0 }
        target.setAccessibilityElement(
            excludesChildren
                ? false
                : (authoredElement ?? (carriesSemantics || pressable ? true : defaults.isElement)))

        if #available(macOS 26.0, *), headingLevel > 0 {
            target.setAccessibilityRole(NSAccessibility.Role(rawValue: "AXHeading"))
        } else if pressable {
            target.setAccessibilityRole(.button)
        } else {
            target.setAccessibilityRole(defaults.role)
        }
    }

    /// The object assistive technology meets for `view`: the native control a
    /// wrapping view presents in its place (`AppKitAccessibilityPresenting`),
    /// or the view itself - and for a control AppKit presents through its
    /// cell, a button, a slider or a stepper, that cell. The cell is the
    /// element there and the view is not, so words written on the view would
    /// reach nobody, and making the view the element would hide the control's
    /// own role. Whether it is the cell is decided once, before any authored
    /// word moves it; the control is looked up each time, because a wrapper
    /// may replace it - a text field becoming a password field.
    private func accessibilityTarget(of view: NSView) -> NSAccessibilityProtocol {
        let control = (view as? AppKitAccessibilityPresenting)?.presentedControl ?? view
        let cell = (control as? NSControl)?.cell
        if accessibilityThroughCell == nil {
            accessibilityThroughCell = cell?.isAccessibilityElement() == true
        }
        if accessibilityThroughCell == true, let cell {
            return cell
        }
        return control
    }

    private var presentableViews: [NSView] {
        if let view { return [view] }
        return children.flatMap(\.presentableViews)
    }

    /// The first native view authored into one structural child slot.
    func firstView(in slot: NodeType) -> NSView? {
        self.slot(slot)?.presentableViews.first
    }

    /// Resolves an image-valued property through the host's resource policy.
    func image(_ property: Prop) -> NSImage? {
        string(property).flatMap { image(named: $0) }
    }

    private func slot(_ type: NodeType) -> MountedNode? {
        children.first { $0.type == type }
    }

    private func radioScope(named group: String?) -> MountedNode {
        guard group != nil else { return parent ?? self }

        var scope = self
        while let ancestor = scope.parent {
            scope = ancestor
            if scope.type == .window { break }
        }
        return scope
    }

    private func radioButtons(named group: String) -> [MountedNode] {
        var matches: [MountedNode] = []
        if type == .radioButton, name(.groupName) == group { matches.append(self) }
        for child in children { matches.append(contentsOf: child.radioButtons(named: group)) }
        return matches
    }

    private func setRadioChecked(_ checked: Bool) {
        (view as? AppKitRadioButtonView)?.setCheckedFromGroup(checked)
    }

    private var nativeMenuItem: NSMenuItem? {
        if type == .menuSeparator {
            if let platformMenuItem { return platformMenuItem }
            let item = NSMenuItem.separator()
            platformMenuItem = item
            return item
        }

        guard type == .menu || type == .menuItem else { return nil }

        let item = platformMenuItem ?? NSMenuItem()
        platformMenuItem = item
        item.title = string(.text) ?? ""
        item.isEnabled = value(.isEnabled)?.bool ?? true
        item.setAccessibilityIdentifier(string(.accessibilityIdentifier))
        item.image = string(.icon).flatMap { image(named: $0) }

        if value(.isDestructive)?.bool == true {
            item.attributedTitle = NSAttributedString(
                string: item.title,
                attributes: [.foregroundColor: NSColor.systemRed])
        } else {
            item.attributedTitle = NSAttributedString(string: item.title)
        }

        if type == .menuItem {
            item.target = self
            item.action = #selector(clicked(_:))
            item.submenu = nil
        } else {
            item.target = nil
            item.action = nil
            let menu = item.submenu ?? NSMenu(title: item.title)
            menu.title = item.title
            menu.autoenablesItems = false
            menu.removeAllItems()
            for child in children {
                if let child = child.nativeMenuItem { menu.addItem(child) }
            }
            item.submenu = menu
        }

        return item
    }

    /// Attaches the view's menu slot directly to AppKit. The slot remains a
    /// StateUI child for identity and sparse updates, but never becomes a
    /// visual child in the native layout.
    private func configureContextMenu() {
        guard let view else { return }
        guard let slot = slot(.contextMenu) else {
            view.menu = nil
            return
        }

        let items = slot.children.compactMap(\.nativeMenuItem)
        guard !items.isEmpty else {
            view.menu = nil
            return
        }

        let menu = view.menu ?? NSMenu()
        menu.autoenablesItems = false
        menu.removeAllItems()
        for item in items { menu.addItem(item) }
        view.menu = menu
    }

    private func popNavigation() {
        guard type == .navigationStack, children.count > 1,
              let handler = events[.popped]
        else { return }

        host?.dispatch(handler, payload: [.number(Double(children.count - 2))])
    }

    private func selectTab(from previous: Int, to selected: Int) {
        guard type == .tabbedView, children.indices.contains(selected) else { return }

        if pagePresented {
            if children.indices.contains(previous) {
                children[previous].setPagePresented(false, reason: .appearance)
            }
            children[selected].setPagePresented(true, reason: .appearance)
        }

        host?.commit(events[.currentPageChanged], payload: [.number(Double(selected))])

        // The window's chrome follows what the reader sees now - its title,
        // its actions, its row of tabs - whether or not the application binds
        // the selection and renders again.
        host?.refreshWindowChrome()
    }

    private func changeSidebarVisibility(to presented: Bool) {
        guard type == .splitView else { return }

        if pagePresented {
            children.first?.setPagePresented(presented, reason: .appearance)
        }

        host?.commit(events[.isSidebarVisibleChanged], payload: [.bool(presented)])
    }

    private func enumeration(_ property: Prop) -> Int32? {
        value(property)?.enumeration
    }

    private func whole(_ property: Prop) -> Int? {
        guard let number = value(property)?.number, number.isFinite else { return nil }
        return Int(number.rounded())
    }

    private func font(fallback: NSFont) -> NSFont {
        let size = value(.fontSize)?.number ?? fallback.pointSize
        let traits = value(.fontAttributes)?.enumeration ?? 0
        var font = name(.fontFamily).flatMap { NSFont(name: $0, size: size) }
            ?? NSFont.systemFont(ofSize: size)

        if traits & 1 == 1,
           let bold = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask) as NSFont? {
            font = bold
        }

        if traits & 2 == 2,
           let italic = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask) as NSFont? {
            font = italic
        }

        return font
    }

    private func attributedLabelText() -> NSAttributedString {
        let baseFont = font(fallback: NSFont.systemFont(ofSize: NSFont.systemFontSize))
        let baseColor = color(.textColor) ?? .labelColor
        let formatted = slot(.spans)
        let runs = formatted?.children ?? [self]
        let result = NSMutableAttributedString()

        for run in runs where run.type == .span || run === self {
            let source = run.string(.text) ?? ""
            let text = run.transformed(source, by: run.enumeration(.textCase))
            let font = run === self ? baseFont : run.font(fallback: baseFont)
            let color = run === self ? baseColor : (run.color(.textColor) ?? baseColor)
            let spacing = run.number(.characterSpacing) ?? number(.characterSpacing) ?? 0
            let decorations = run.enumeration(.textDecorations)
                ?? enumeration(.textDecorations) ?? 0
            let lineHeight = run.number(.lineHeight) ?? number(.lineHeight)
            var attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: color,
                .kern: spacing,
            ]

            if run !== self, let background = run.color(.background) {
                attributes[.backgroundColor] = background
            }
            if decorations & 1 == 1 {
                attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
            }
            if decorations & 2 == 2 {
                attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
            }
            if let lineHeight, lineHeight.isFinite, lineHeight > 0 {
                let paragraph = NSMutableParagraphStyle()
                let height = font.boundingRectForFont.height * lineHeight
                paragraph.minimumLineHeight = height
                paragraph.maximumLineHeight = height
                attributes[.paragraphStyle] = paragraph
            }

            result.append(NSAttributedString(string: text, attributes: attributes))
        }

        return result
    }

    private func effectiveMaximumLines() -> Int {
        switch enumeration(.lineBreak) {
        case 0, 3, 4, 5: return 1
        default: return max(0, whole(.maximumLines) ?? 0)
        }
    }

    /// The text a field shows from its state. The value this frame carries
    /// comes first: a reader's report reaches the core's store only when its
    /// jobs run, so reading the store here would write the field back one
    /// keystroke behind the reader.
    private func attachedTextValue() -> String? {
        if let binding = driven[.text], binding.mode != .in,
           case .text(let text)? = drivenValues[.text] ?? core.value(for: binding) {
            return text
        }

        if driven[.text] == nil { return string(.text) ?? "" }
        return nil
    }

    private func transformed(_ text: String, by transform: Int32?) -> String {
        switch transform {
        case 2: return text.lowercased()
        case 3: return text.uppercased()
        default: return text
        }
    }

    func color(_ property: Prop) -> NSColor? {
        value(property).flatMap(nsColor)
    }

    private func image(named name: String) -> NSImage? {
        host?.image(named: name)
    }

    private func value(_ property: Prop) -> HostValue? {
        if driven[property].map({ $0.mode != .in }) == true {
            return resolvedValue(property)
        }

        return host?.presentedPropertyValue(mount: mount, property: property)
            ?? resolvedValue(property)
    }

    private func standingValue(_ property: Prop, target: HostValue?) -> HostValue? {
        if let presented = host?.presentedPropertyValue(mount: mount, property: property) {
            return presented
        }

        if type == .window,
           let value = host?.standingWindowValue(for: self, property: property) {
            return value
        }

        switch (type, property) {
        case (_, .opacity):
            return .number(Double(view?.alphaValue ?? 1))
        case (.slider, .value):
            return (view as? AppKitSliderView).map { .number($0.doubleValue) }
        case (.progressBar, .progress):
            return (view as? AppKitProgressView).map { .number($0.doubleValue) }
        default:
            break
        }

        if let value = resolvedValue(property) { return value }
        guard AppKitTransitionSurface.presents(property, on: type) else { return nil }

        switch property {
        case .margin, .padding:
            return .numbers([0, 0, 0, 0])
        case .spacing, .rowSpacing, .columnSpacing:
            return .number(0)
        case .strokeWidth:
            return .number(1)
        case .strokeDashOffset, .x1, .y1, .x2, .y2:
            return .number(0)
        case .strokeMiterLimit:
            return .number(10)
        case .cornerRadius:
            if target?.number != nil {
                return .number(0)
            }
            if let radii = target?.numbers, radii.count == 4 {
                return .numbers(Array(repeating: 0, count: radii.count))
            }
            return nil
        case .rotation, .translationX, .translationY:
            return .number(0)
        case .scale:
            return .number(1)
        case .scaleX, .scaleY:
            return .number(resolvedValue(.scale)?.number ?? 1)
        case .renderTransform:
            return .values([
                .number(1), .number(0), .number(0),
                .number(1), .number(0), .number(0),
            ])
        default:
            return nil
        }
    }

    private func transformComponents(_ property: Prop) -> [Double]? {
        guard let components = value(property)?.values, components.count == 6 else {
            return nil
        }

        let numbers = components.compactMap(\.number)
        return numbers.count == components.count ? numbers : nil
    }

    private func resolvedValue(_ property: Prop) -> HostValue? {
        guard let binding = driven[property], binding.mode != .in else {
            return properties[property]
        }

        guard let state = drivenValues[property] ?? core.value(for: binding) else {
            return properties[property]
        }

        switch (binding.kind, state) {
        case (.text, .text(let text)):
            return .string(text)

        case (.plain, .lanes(let lanes)):
            return value(property, lanes: lanes)

        case (.property, let carried):
            let presented = host?.presentedValue(for: binding, from: carried) ?? carried
            guard let journey = StateUIHost.journey(from: presented) else {
                return properties[property]
            }
            return value(property, lanes: journey.value)

        default:
            return properties[property]
        }
    }

    private func value(_ property: Prop, lanes: [Double]) -> HostValue? {
        guard !lanes.isEmpty else { return nil }

        if Self.colorProperties.contains(property), lanes.count >= 4 {
            func channel(_ value: Double) -> UInt8 {
                UInt8(min(max((value * 255).rounded(), 0), 255))
            }

            return .color(
                red: channel(lanes[0]),
                green: channel(lanes[1]),
                blue: channel(lanes[2]),
                alpha: channel(lanes[3]))
        }

        if Self.booleanProperties.contains(property) {
            return .bool(lanes[0] != 0)
        }

        if Self.enumerationProperties.contains(property) {
            return .enumeration(Int32(lanes[0].rounded()))
        }

        return lanes.count == 1 ? .number(lanes[0]) : .numbers(lanes)
    }

    private func insets(_ property: Prop) -> NSEdgeInsets {
        guard let numbers = value(property)?.numbers, numbers.count >= 4 else {
            return NSEdgeInsets()
        }

        return NSEdgeInsets(
            top: numbers[1], left: numbers[0], bottom: numbers[3], right: numbers[2])
    }

    /// A negative request is StateUI's explicit "measure me" sentinel. Keep
    /// it out of both Auto Layout and the frame-based layout algorithms so the
    /// native control's fitting size remains authoritative.
    private func requested(_ property: Prop) -> CGFloat? {
        guard let value = number(property), value.isFinite, value >= 0 else { return nil }
        return CGFloat(value)
    }

    private func gridLengths(_ property: Prop) -> [AppKitGridLength] {
        value(property)?.values?.compactMap(AppKitGridLength.init) ?? []
    }

    private func placement(_ property: Prop) -> HostPlacementRun? {
        guard let binding = driven[property], binding.kind == .placement,
              let carried = drivenValues[property] ?? core.value(for: binding)
        else { return nil }

        return StateUIHost.placements(from: carried)
    }

    private func textAlignment(_ value: Int32?) -> NSTextAlignment {
        switch value {
        case 1: return .center
        case 2: return .right
        default: return .left
        }
    }

    private func buttonImagePosition(imageOnly: Bool) -> NSControl.ImagePosition {
        guard !imageOnly else { return .imageOnly }
        let position = enumeration(.iconPosition)

        switch position {
        case 1: return .imageAbove
        case 2: return .imageTrailing
        case 3: return .imageBelow
        default: return .imageLeading
        }
    }

    private func imageScaling(_ aspect: Int32?) -> NSImageScaling {
        switch aspect {
        case 2: return .scaleAxesIndependently
        case 3: return .scaleNone
        default: return .scaleProportionallyUpOrDown
        }
    }

    private func imageAspect(_ value: Int32?) -> Aspect {
        value.flatMap(Aspect.init(rawValue:)) ?? .fit
    }

    private func lineBreakMode(_ mode: Int32?) -> NSLineBreakMode {
        switch mode {
        case 0: return .byClipping
        case 1: return .byWordWrapping
        case 2: return .byCharWrapping
        case 3: return .byTruncatingHead
        case 4: return .byTruncatingTail
        case 5: return .byTruncatingMiddle
        default: return .byWordWrapping
        }
    }

    private func configureFrameObservation() {
        guard view != nil else { return }
        let wanted = driven[.frame] != nil || events[.frameChanged] != nil

        if !wanted {
            if observesFrame {
                NotificationCenter.default.removeObserver(
                    self, name: NSView.frameDidChangeNotification, object: nil)
                NotificationCenter.default.removeObserver(
                    self, name: NSView.boundsDidChangeNotification, object: nil)
                frameObservedViews.removeAll(keepingCapacity: true)
                observesFrame = false
            }
            return
        }

        if !observesFrame {
            observesFrame = true
        }

        refreshFrameObservationChain()
        queueFrameReport()
    }

    /// A stationary child's window-space origin changes when an ancestor moves
    /// or a clip view scrolls. Observe the current native chain and rebuild it
    /// after reparenting instead of treating the child's frame as sufficient.
    private func refreshFrameObservationChain() {
        guard observesFrame, let view else { return }
        var chain: [NSView] = []
        var current: NSView? = view

        while let candidate = current {
            chain.append(candidate)
            if candidate === view.window?.contentView { break }
            current = candidate.superview
        }

        let unchanged = chain.count == frameObservedViews.count
            && zip(chain, frameObservedViews).allSatisfy { $0 === $1 }
        guard !unchanged else { return }

        NotificationCenter.default.removeObserver(
            self, name: NSView.frameDidChangeNotification, object: nil)
        NotificationCenter.default.removeObserver(
            self, name: NSView.boundsDidChangeNotification, object: nil)
        frameObservedViews = chain

        for observed in chain {
            observed.postsFrameChangedNotifications = true
            observed.postsBoundsChangedNotifications = true
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(frameDidChange(_:)),
                name: NSView.frameDidChangeNotification,
                object: observed)
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(frameDidChange(_:)),
                name: NSView.boundsDidChangeNotification,
                object: observed)
        }
    }

    private func configureGestures() {
        guard let view else { return }

        if events[.tapped] != nil {
            let recognizer: AppKitTapRecognizer

            if let existing = tapRecognizer {
                recognizer = existing
            } else {
                recognizer = AppKitTapRecognizer { [weak self] in self?.tapped() }
                tapRecognizer = recognizer
                view.addGestureRecognizer(recognizer)
            }

            recognizer.apply(tapCount: whole(.tapCount) ?? 1)
        } else if let recognizer = tapRecognizer {
            view.removeGestureRecognizer(recognizer)
            tapRecognizer = nil
        }

        (view as? AppKitHitTestView)?.pressAction = events[.tapped] == nil
            ? nil
            : { [weak self] in self?.tapped() }

        if events[.swiped] != nil {
            let recognizer: AppKitSwipeRecognizer
            if let existing = swipeRecognizer {
                recognizer = existing
            } else {
                recognizer = AppKitSwipeRecognizer { [weak self] direction in
                    self?.swiped(direction)
                }
                swipeRecognizer = recognizer
                view.addGestureRecognizer(recognizer)
            }
            recognizer.directions = enumeration(.swipeDirection) ?? 15
            recognizer.threshold = max(
                0,
                number(.swipeThreshold).map { CGFloat($0) } ?? 40)
        } else if let recognizer = swipeRecognizer {
            view.removeGestureRecognizer(recognizer)
            swipeRecognizer = nil
        }

        let panX = whole(.panXChannel).flatMap { $0 == 0 ? nil : Int32($0) }
        let panY = whole(.panYChannel).flatMap { $0 == 0 ? nil : Int32($0) }
        let wantsPan = events[.panUpdated] != nil || panX != nil || panY != nil
        if wantsPan {
            let recognizer: AppKitPanRecognizer
            if let existing = panRecognizer {
                recognizer = existing
            } else {
                recognizer = AppKitPanRecognizer { [weak self] phase, total in
                    self?.panChanged(phase, total: total)
                }
                panRecognizer = recognizer
                view.addGestureRecognizer(recognizer)
            }

            // AppKit's stable pan contract is a primary-pointer drag. The
            // multi-touch count API before macOS 26 refers to Touch Bar input,
            // so an authored count other than one cannot truthfully match here.
            recognizer.isEnabled = whole(.panTouchCount).map { $0 == 1 } ?? true
        } else if let recognizer = panRecognizer {
            view.removeGestureRecognizer(recognizer)
            panRecognizer = nil
        }

        if events[.pinchUpdated] != nil {
            if pinchRecognizer == nil {
                let recognizer = AppKitPinchRecognizer { [weak self] phase, scale, origin in
                    self?.pinchChanged(phase, scale: scale, origin: origin)
                }
                pinchRecognizer = recognizer
                view.addGestureRecognizer(recognizer)
            }
        } else if let recognizer = pinchRecognizer {
            view.removeGestureRecognizer(recognizer)
            pinchRecognizer = nil
        }

        let pointerEvents = [
            Event.pointerEntered, .pointerExited, .pointerMoved, .pointerPressed, .pointerReleased,
        ]
        if pointerEvents.contains(where: { events[$0] != nil }) {
            let recognizer: AppKitPointerRecognizer
            if let existing = pointerRecognizer {
                recognizer = existing
            } else {
                recognizer = AppKitPointerRecognizer { [weak self] report, point in
                    self?.pointerChanged(report, point: point)
                }
                pointerRecognizer = recognizer
            }
            recognizer.install(on: view)
        } else if let recognizer = pointerRecognizer {
            recognizer.detach()
            pointerRecognizer = nil
        }
    }

    @objc private func frameDidChange(_ notification: Notification) {
        queueFrameReport()
    }

    private func queueFrameReport() {
        guard !frameQueued else { return }
        frameQueued = true

        DispatchQueue.main.async { [weak self] in
            self?.flushFrameReport()
        }
    }

    private func flushFrameReport() {
        frameQueued = false
        refreshFrameObservationChain()
        guard let view, let content = view.window?.contentView else { return }

        let parentFrame = topLeftFrame(view.frame, in: view.superview)
        let windowFrame = topLeftFrame(view.convert(view.bounds, to: content), in: content)
        let safeArea = topLeftFrame(content.safeAreaRect, in: content)
        let report = [
            parentFrame.minX, parentFrame.minY, parentFrame.width, parentFrame.height,
            windowFrame.minX, windowFrame.minY,
            windowFrame.minX - safeArea.minX, windowFrame.minY - safeArea.minY,
        ].map(Double.init)

        guard report != lastFrameReport else { return }
        lastFrameReport = report

        let reported = driven[.frame].map {
            host?.report(.lanes(Array(report.prefix(4))), through: $0) ?? false
        } ?? false

        if let handler = events[.frameChanged] {
            host?.dispatch(handler, payload: [.numbers(report)])
        } else if reported {
            host?.pump()
        }
    }

    func flushFrameReportForTesting() {
        flushFrameReport()
    }

    var frameReportQueuedForTesting: Bool { frameQueued }

    private func topLeftFrame(_ frame: NSRect, in parent: NSView?) -> NSRect {
        guard let parent, !parent.isFlipped else { return frame }
        return NSRect(
            x: frame.minX,
            y: parent.bounds.height - frame.maxY,
            width: frame.width,
            height: frame.height)
    }

    private static let colorProperties: Set<Prop> = [
        .background, .barBackgroundColor, .barForegroundColor, .borderColor, .color,
        .indicatorColor, .placeholderColor, .selectedIndicatorColor, .textColor, .tint,
    ]

    private static let pageTypes: Set<NodeType> = [
        .page, .navigationStack, .tabbedView, .splitView,
    ]

    /// Several visible windows' worth, but never an unbounded history of rows.
    private static let recyclingCapacity = 32

    private static let booleanProperties: Set<Prop> = [
        .allowDrop, .hidesWhenInactive, .canDrag, .floatsOnTop, .growsWithText, .ignoresInput,
        .isAnimating, .clipsContent, .isDestructive,
        .isEnabled, .isMaximizable, .isMinimizable,
        .isOpaque, .isOpen, .isPassword, .isSidebarVisible, .isReadOnly,
        .isRefreshEnabled, .isRefreshing, .isRunning, .isScrollEnabled,
        .showsUserLocation, .isSpellCheckEnabled, .isTextPredictionEnabled,
        .isOn, .isTrafficEnabled, .isVisible, .isZoomEnabled, .letsInputThrough,
        .showsClearButton,
    ]

    private static let enumerationProperties: Set<Prop> = [
        .aspect, .layoutDirection, .fontAttributes,
        .horizontalAlignment, .horizontalScrollBarVisibility,
        .horizontalTextAlignment, .inputPurpose,
        .lineBreak, .orientation, .returnKey, .textDecorations, .textCase,
        .verticalAlignment, .verticalScrollBarVisibility, .verticalTextAlignment,
    ]
}

#endif
