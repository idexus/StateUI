// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
import QuartzCore
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@_spi(Host) import StateUIApple

/// The AppKit runtime: the mounted tree over AppKit views, the scenes and windows around it, and the turn.
/// Design: docs/design/platforms/appkit/runtime.md#the-appkit-runtime
@MainActor
final class AppKitRenderer {
    /// What the host says for whoever reads its log: standard error, or wherever a test listens.
    static var log = HostLog(host: "AppKit")

    let resourceDirectory: URL?
    let presentsWindows: Bool
    let preferences: UserDefaults
    /// Pictures made lately, which the system may let go of under memory pressure.
    let images = NSCache<AppKitPictureKey, NSImage>()

    /// Every picture made that something still holds - a view showing it: asked for again, it is the same picture.
    private let held = NSMapTable<AppKitPictureKey, NSImage>.strongToWeakObjects()
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
        startRuntime {
            environment.start(reportingChanges: { [weak self] report in self?.runtime.environmentChanged(report) })
        }
        startTurns()
    }

    /// Starts the runtime in the one order every host keeps (`HostRuntime.start`): `watching` begins what follows
    /// the environment once its first facts are told - nothing in a test host.
    /// Design: docs/design/host/runtime.md#starting
    func startRuntime(watching: () -> Void = {}) {
        started = true
        runtime.start(
            realizing: AppKitRegistrations.registry.realization, unrealized: AppKitRealization.unrealized,
            register: AppKitRealization.register,
            environment: {
                configureEnvironment()
                watching()
            },
            kept: hydratePersistentState,
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

        core.setApplicationInfo(SystemFacts.application)
    }

    func machineModel() -> String {
        var size = 0
        guard sysctlbyname("hw.model", nil, &size, nil, 0) == 0, size > 0 else { return "" }

        var bytes = [CChar](repeating: 0, count: size)
        guard sysctlbyname("hw.model", &bytes, &size, nil, 0) == 0 else { return "" }
        let end = bytes.firstIndex(of: 0) ?? bytes.endIndex
        return String(decoding: bytes[..<end].map(UInt8.init(bitPattern:)), as: UTF8.self)
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

    /// The window element `window` shows, or the one it stands over as a sheet; else the tree's first.
    func element(of window: NSWindow) -> MountedElement? {
        var native: NSWindow? = window
        while let each = native {
            if let shown = roster.windows.first(where: { $0.controller.window === each }) { return shown.element }
            native = each.sheetParent
        }
        return roster.windows.first?.element
    }

    /// A window's first responder moved. Every element that follows its focus
    /// is told once the move has settled: AppKit hands the focus through
    /// passing holders on its way - the window among them - within one turn.
    func focusMoved() {
        guard !focusReportQueued else { return }
        focusReportQueued = true

        Task { @MainActor [weak self] in
            guard let self else { return }
            focusReportQueued = false
            runtime.tree.root?.reportFocus(in: runtime) { element in
                (element.native as? AppKitElement)?.view.map { AppKitFocus.holds($0, $0.window?.firstResponder) }
            }
        }
    }

    /// The native image for one resource name, loaded once for this renderer.
    func image(named name: String) -> NSImage? {
        image(.file(name))
    }

    /// The native image for a picture, made once for this renderer: a file of the application's, the SF Symbol for
    /// an icon, or the bytes decoded at a point a pixel. A symbol is a template, drawn in the colour of what holds it.
    /// Reapplying an unchanged picture hands a native view the image it already shows, so nothing reads the file
    /// again, no measurement is forgotten and a bar or a tab row finds nothing changed.
    func image(_ picture: HostPicture) -> NSImage? {
        let key = AppKitPictureKey(picture)
        if let kept = images.object(forKey: key) ?? held.object(forKey: key) {
            images.setObject(kept, forKey: key)
            return kept
        }
        let made: NSImage? = switch picture {
        case .file(let name): loadImage(named: name)
        case .icon(let icon): NSImage(systemSymbolName: icon.sfSymbol, accessibilityDescription: nil)
        case .bytes(let bytes): NSImage(data: Data(bytes))
        }
        if let made {
            images.setObject(made, forKey: key)
            held.setObject(made, forKey: key)
        }
        return made
    }

    /// The picture `name` stands for: the file of the name, else its drawing, by the host layer's rule.
    func loadImage(named name: String) -> NSImage? {
        for file in PictureArithmetic.files(for: name) {
            if let url = resourceDirectory?.appendingPathComponent(file), let image = NSImage(contentsOf: url) {
                return image
            }
        }
        return nil
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

/// A picture as the key of a renderer's images.
final class AppKitPictureKey: NSObject {
    let picture: HostPicture

    init(_ picture: HostPicture) {
        self.picture = picture
    }

    override var hash: Int { picture.hashValue }

    override func isEqual(_ object: Any?) -> Bool {
        (object as? AppKitPictureKey)?.picture == picture
    }
}

extension AppKitRenderer: HostPresenter {
    func presentRendered(touchedChrome: Bool) {
        if touchedChrome { synchronizeWindows() }
    }

    func presentFrame(movedChrome: Bool) {
        guard movedChrome else { return }
        for controller in windowControllers { controller.followFrame(in: runtime) }
    }

    func perform(_ call: HostActCall) {
        acts.perform(call)
    }

    func focus(_ element: MountedElement) {
        acts.focus(element)
    }
}
#endif
