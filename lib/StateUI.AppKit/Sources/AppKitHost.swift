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

/// The AppKit runtime: the mounted tree over AppKit views, the scenes and windows around it, and the turn.
/// Unchecked Sendable: every mutation is on MainActor; the doorbell only posts `pump()` to the main queue.
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
    private let core = CoreLink()
    private let walker: Walker
    private let stateChannels: StateChannels
    private let describedMotion: DescribedMotion
    let layoutMotion: LayoutMotion
    private let displayCycle: DisplayCycle
    private let images = NSCache<NSString, NSImage>()
    private let frameClock: AppKitFrameClock
    private let reducesMotion: () -> Bool
    private let intake = PatchIntake()
    private lazy var actPerformer = AppKitActPerformer(renderer: self)
    private var focusReportQueued = false

    /// The mounted tree; each element's AppKit half is an `AppKitElement`.
    private(set) lazy var tree = MountedTree(
        core: core,
        intake: intake,
        stateChannels: stateChannels,
        describedMotion: describedMotion,
        layoutMotion: layoutMotion,
        now: frameClock.now,
        reducesMotion: reducesMotion,
        makeNative: { [unowned self] element in AppKitElement(element, host: self) })
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
        let frameClock = clock.map { AppKitFrameClock(now: $0) } ?? AppKitFrameClock()
        self.frameClock = frameClock
        self.reducesMotion = reducesMotion
        let walker = Walker()
        self.walker = walker
        stateChannels = StateChannels(walker: walker)
        describedMotion = DescribedMotion(walker: walker)
        layoutMotion = LayoutMotion(
            walker: walker, now: frameClock.now, reducesMotion: reducesMotion)
        displayCycle = DisplayCycle(
            core: core,
            clock: frameClock,
            walker: walker,
            stateChannels: stateChannels,
            describedMotion: describedMotion,
            layoutMotion: layoutMotion,
            reducesMotion: reducesMotion)
        frameClock.onFrame = { [weak self] now in self?.displayCycle.frame(now: now) }
        layoutMotion.onStart = { [weak self] in self?.displayCycle.hold() }
        tree.onAnimation = { [weak self] in self?.displayCycle.hold() }
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
        if synchronizingWindows || readerTransactionDepth > 0 || intake.isApplying {
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
    func requestFrames(for scroller: AppKitScrollView) {
        framedScrollers.add(scroller)
        displayCycle.hold()
    }

    /// Lets `scroller` go of the display's frames, as it leaves the tree.
    func stopFrames(for scroller: AppKitScrollView) {
        framedScrollers.remove(scroller)
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

    /// One turn of the host: the jobs a resumed handler left, a pending cycle,
    /// a render when the core needs one, then the acts - on the interface the
    /// render has just brought up to date.
    func pump() {
        _ = core.runJobs()

        if tree.root != nil, core.cyclesPending {
            displayCycle.drain(now: frameClock.now())
        }

        if tree.root == nil || core.needsRender {
            let rendered = core.render(baseline: intake.baseline)

            if !intake.take(rendered.root, generation: rendered.generation, apply: {
                tree.apply($0, complete: rendered.complete)
            }) {
                // REFUSED, then asked for whole once: a complete render is
                // reconciled against the tree the core holds, so every identity,
                // handler and state survives it.
                NSLog("StateUI AppKit: the interface drifted and is asked for whole: %@",
                      intake.lastDrift ?? "")
                let complete = core.render(baseline: 0)
                intake.take(complete.root, generation: complete.generation, apply: {
                    tree.apply($0, complete: complete.complete)
                })
            }

            displayCycle.presentStateChannels()

            let created = tree.root?.takeCreatedHandlers() ?? []
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

        // THE ACTS LAND ON THE INTERFACE THEIR HANDLER CHANGED: taken once the
        // render is in, so a handler that enables a field and focuses it in the
        // same breath finds it enabled.
        for call in core.takeActCalls() {
            actPerformer.perform(call)
        }
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

    /// The native view of the element with `id`, as the tree stands.
    func presentedView(id: ElementId) -> NSView? {
        tree.root?.first(id: id)?.appKit.view
    }

    /// The window the reader is looking at: the key window, else the main one.
    var readerWindow: NSWindow? {
        NSApp.keyWindow ?? orderedWindowControllers.first?.window
    }

    /// A window's first responder moved. Every element that follows its focus
    /// is told once the move has settled: AppKit hands the focus through
    /// passing holders on its way - the window among them - within one turn.
    func focusMoved() {
        guard !focusReportQueued else { return }
        focusReportQueued = true

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            focusReportQueued = false
            tree.root?.appKit.reportFocus()
        }
    }

    var frameClockWindowForTesting: NSWindow? { frameClock.window }

    var describedMotionActiveForTesting: Bool { describedMotion.isActive }

    /// The AppKit half of the mounted root.
    var rootElementForTesting: AppKitElement? { tree.root?.appKit }

    func viewForTesting(id: ElementId) -> NSView? {
        tree.root?.first(id: id)?.appKit.view
    }

    func viewsForTesting(id: ElementId) -> [NSView] {
        tree.root?.all(id: id).compactMap(\.appKit.view) ?? []
    }

    func applyForTesting(_ patch: HostPatch) {
        intake.take(patch, generation: intake.baseline &+ 1) { tree.apply($0, complete: true) }

        synchronizeWindows()
        flushQueuedEvents()
    }

    /// What made the last refused message drift.
    var driftForTesting: String? { intake.lastDrift }

    /// The generation the host quotes on its next render.
    var baselineForTesting: Int32 { intake.baseline }

    /// Loses the element that presents `view`, as a host that dropped part of
    /// its tree would.
    func forgetForTesting(_ view: NSView) {
        tree.root?.forgetForTesting { $0.appKit.view === view }
        view.removeFromSuperview()
    }

    func stepTripsForTesting() {
        displayCycle.stepTrips(now: frameClock.now(), reducesMotion: reducesMotion())
        displayCycle.hold()
    }

    func displayFrameForTesting() {
        displayCycle.frame(now: frameClock.now())
    }

    var frameClockRunningForTesting: Bool { frameClock.isRunning }

    var tripsMovingForTesting: Bool { walker.isMoving }

    var channelCountForTesting: Int { stateChannels.count }

    func applyStateForTesting(_ state: Int32, value: HostStateValue) {
        let impact = tree.present(states: [state: value], properties: [:])
        if impact.windowChrome { synchronizeWindows() }
    }

    func applyStatesForTesting(_ valuesByState: [Int32: HostStateValue]) {
        let impact = valuesByState.isEmpty
            ? FrameImpact.none
            : tree.present(states: valuesByState, properties: [:])
        if impact.windowChrome { synchronizeWindows() }
    }

    func closeForTesting() {
        for scene in orderedScenes.reversed() { scene.closeFromTree() }
        scenes.removeAll()
        sceneOrder.removeAll()
        for window in restoredWindows.values { window.close() }
        restoredWindows.removeAll()
        tree.root?.leave()
        frameClock.stop()
    }

    /// The native image for one resource name, loaded once for this
    /// renderer. Reapplying an unchanged source hands a native view the image
    /// it already shows, so nothing reads the file again and no measurement is
    /// forgotten.
    func image(named name: String) -> NSImage? {
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

    func standingWindowValue(
        for node: AppKitElement,
        property: Prop
    ) -> HostValue? {
        orderedWindowControllers.first(where: { $0.presents(node) })?
            .standingValue(property)
    }

}

/// An element's view, placed by the layout motion of the layout it stands in.
extension AppKitElement: PlacedView {
    var placedFrame: Rect {
        get { view?.frame.placed ?? Rect(0, 0, 0, 0) }
        set { view?.frame = NSRect(placed: newValue) }
    }
}

extension AppKitRenderer: FramePresenter {
    var wantsFrames: Bool { framedScrollers.anyObject != nil }

    /// Lets every moving scroller say what the frame saw it do, as one user transaction;
    /// a scroller that stands and has said everything lets the clock go.
    func commitUserReports(now: Double) {
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
        let impact = tree.present(states: states, properties: properties)
        if impact.windowChrome { synchronizeWindows() }
    }

    func renderIfNeeded() {
        if eventSink == nil, core.needsRender { pump() }
    }
}

#endif
