// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
import QuartzCore
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The AppKit runtime: the mounted tree over AppKit views, the scenes and windows around it, and the turn.
/// Design: docs/design/platforms/appkit/runtime.md#the-appkit-runtime
@MainActor
final class AppKitRenderer {
    /// What the host says for whoever reads its log: standard error, or wherever a test listens.
    static var log = HostLog(host: "AppKit")

    let resourceDirectory: URL?
    let presentsWindows: Bool
    let preferences: UserDefaults
    let images = NSCache<NSString, NSImage>()
    let frameClock: AppKitFrameClock
    let reducesMotion: () -> Bool

    /// The parts every host holds alike - the core's link, the motions, the display cycle, the mounted tree and the
    /// turn - each element's AppKit half an `AppKitElement`.
    private(set) lazy var runtime = HostRuntime(
        clock: frameClock, reducesMotion: reducesMotion,
        makeNative: { [unowned self] element in AppKitElement(element, host: self) },
        log: { AppKitRenderer.log.error($0) }, views: { AppKitElement.liveViewCount })

    private(set) lazy var environment = AppKitEnvironment(core: runtime.core)
    /// AppKit's part of the acts every host performs, and the host layer's performer of them.
    lazy var actToolkit = AppKitActToolkit(renderer: self)
    /// AppKit's part of the files the user opens and saves, and of what macOS launches.
    lazy var fileToolkit = AppKitFileToolkit(renderer: self)
    lazy var acts = HostActPerformer(
        toolkit: actToolkit, files: fileToolkit, tree: { [unowned self] in runtime.tree })
    var focusReportQueued = false

    /// The windows the tree holds, each with its controller, in the tree's order.
    let roster = WindowRoster<AppKitWindowController>()

    /// What each scene keeps for the system's window restoration, by the scene's key.
    var sceneValues = SceneValues()
    /// The turn after every pass of the main run loop, once the host has started.
    var turns: RunLoopTurns?
    /// Whether the platform's first window came - one the system restored before the start.
    var connectedFirstWindow = false
    var started = false
    weak var activeWindow: AppKitWindowController?
    /// The windows the system restored, waiting for the tree to claim them.
    let restored = RestoredWindows<NSWindow>()
    var pageMenuInsertions: [(menu: NSMenu, item: NSMenuItem)] = []
    var windowSynchronizationCountForTesting = 0

    init(
        resourceDirectory: URL?,
        presentsWindows: Bool = true,
        preferences: UserDefaults = .standard,
        clock: (() -> Double)? = nil,
        reducesMotion: @escaping () -> Bool = {
            NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        }
    ) {
        self.resourceDirectory = resourceDirectory
        self.presentsWindows = presentsWindows
        self.preferences = preferences
        frameClock = clock.map { AppKitFrameClock(now: $0) } ?? AppKitFrameClock()
        self.reducesMotion = reducesMotion
        runtime.presenter = self
    }

    func start() {
        environment.start(reportingChanges: { [weak self] report in self?.runtime.environmentChanged(report) })
        startRuntime()
        startTurns()
    }

    func startRuntime() {
        started = true
        runtime.start(
            realizing: AppKitRegistrations.registry.realization, unrealized: AppKitRealization.unrealized,
            environment: configureEnvironment, kept: hydratePersistentState,
            windows: {
                if !connectedFirstWindow {
                    runtime.connectWindow()
                    connectedFirstWindow = true
                }
                runtime.pump.turn()
            })
    }

    func configureEnvironment() {
        let process = ProcessInfo.processInfo
        let bundle = Bundle.main
        let core = runtime.core

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
                width: screen.frame.width * scale, height: screen.frame.height * scale, density: scale,
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

    /// Tells a window's or a scene's phase - or what the user settled on a native control, after the phases it
    /// moved - in its turn: rendered before anything after it.
    func tellPhase(_ handler: Int32?, payload: [HostValue] = []) {
        if let handler { runtime.pump.handlers.enqueuePhase(handler, payload: payload) }
        runtime.pump.turn()
    }

    /// Takes a turn after every pass of the main run loop, where the core has work for one.
    /// Design: docs/design/host/runtime.md#the-turn-on-apple
    func startTurns() {
        guard turns == nil else { return }
        turns = RunLoopTurns(runtime.pump)
    }

    /// The native view of the element with `id`, as the tree stands.
    func presentedView(id: ElementID) -> NSView? {
        runtime.tree.root?.first(id: id)?.appKit.view
    }

    /// The window the user is looking at: the key window, else the tree's first.
    var userWindow: NSWindow? {
        NSApp.keyWindow ?? windowControllers.first?.window
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
            runtime.tree.root?.appKit.reportFocus()
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

    /// The picture `name` stands for: the file of the name, else its drawing, by the host layer's rule.
    func loadImage(named name: String) -> NSImage? {
        for file in PictureArithmetic.files(for: name) {
            if let url = resourceDirectory?.appendingPathComponent(file), let image = NSImage(contentsOf: url) {
                return image
            }
        }
        return NSImage(systemSymbolName: "swift", accessibilityDescription: name)
    }
}

/// An element's view, placed by the layout motion of the layout it stands in - a label at the size its place
/// travels to, its words standing there meanwhile.
extension AppKitElement: PlacedView {
    var placedFrame: Rect {
        get { view?.frame.placed ?? Rect(0, 0, 0, 0) }
        set {
            let size = wordsRoom ?? newValue
            view?.frame = NSRect(x: newValue.x, y: newValue.y, width: size.width, height: size.height)
            isPlaced = true
        }
    }

    func travels(to destination: Rect?) {
        if type == .text { wordsRoom = destination }
    }
}

extension AppKitRenderer: HostPresenter {
    func presentRendered() {
        synchronizeWindows()
    }

    func presentFrame(movedChrome: Bool) {
        if movedChrome { synchronizeWindows() }
    }

    func perform(_ call: HostActCall) {
        acts.perform(call)
    }
}
#endif
