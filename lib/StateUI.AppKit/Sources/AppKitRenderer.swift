// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
import QuartzCore
@_spi(Host) import StateUI

/// The AppKit runtime: the mounted tree over AppKit views, the scenes and windows around it, and the turn.
/// Unchecked Sendable: every mutation is on MainActor; the doorbell only posts `pump()` to the main queue.
@MainActor
final class AppKitRenderer: @unchecked Sendable {
    struct QueuedEvent {
        let handler: Int32
        let payload: [HostValue]
        let restorationIdentifier: String?

        /// A phase report, rendered before the next report moves the phase
        /// again.
        var isPhase = false
    }

    let resourceDirectory: URL?
    let presentsWindows: Bool
    let eventSink: ((Int32, [HostValue]) -> Void)?
    let preferences: UserDefaults
    let core = CoreLink()
    let walker: Walker
    let stateChannels: StateChannels
    let describedMotion: DescribedMotion
    let layoutMotion: LayoutMotion
    let displayCycle: DisplayCycle
    let images = NSCache<NSString, NSImage>()
    let frameClock: AppKitFrameClock
    let reducesMotion: () -> Bool
    let intake = PatchIntake()
    lazy var actPerformer = AppKitActPerformer(renderer: self)
    var focusReportQueued = false

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
    var scenes: [ElementId: AppKitSceneController] = [:]
    var sceneOrder: [ElementId] = []

    /// The scrollers moving or waiting to report, each given the display's
    /// frames until it stands and has said everything.
    let framedScrollers = NSHashTable<AppKitScrollView>.weakObjects()
    var doorbellStarted = false
    var connectedInitialScene = false
    var started = false
    var synchronizingWindows = false

    /// Whether the queue is being delivered. A render inside the delivery
    /// queues what it raises behind what already waits, in order.
    var deliveringEvents = false
    var readerTransactionDepth = 0
    var readerTransactionChangedState = false
    var queuedEvents: [QueuedEvent] = []
    weak var activeWindow: AppKitWindowController?
    var applicationIsHidden = false
    let restorationQueue = AppKitRestorationQueue()
    var restoredWindows: [String: NSWindow] = [:]
    var offeredRestorations = Set<String>()
    var abandonmentScheduled = false
    var pageMenuInsertions: [(menu: NSMenu, item: NSMenuItem)] = []
    var windowSynchronizationCountForTesting = 0

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

    func startRuntime() {
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

    func configureEnvironment() {
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

    func machineModel() -> String {
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

    func startDoorbell() {
        guard !doorbellStarted else { return }
        doorbellStarted = true

        DispatchQueue.global(qos: .userInteractive).async { [self] in
            while true {
                _ = core.waitForWork()
                DispatchQueue.main.async { [self] in pump() }
            }
        }
    }

    /// Delivers what waits, in order. A phase is state the application
    /// watches, so each phase report is rendered before the next report moves
    /// the phase again: a push that reports a page's arrival and its
    /// navigation in one native move still shows both.
    func flushQueuedEvents() {
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

    func loadImage(named name: String) -> NSImage? {
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
