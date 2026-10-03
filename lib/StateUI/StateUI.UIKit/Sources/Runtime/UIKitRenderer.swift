// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The UIKit host's runtime: the host layer's (`HostRuntime`) over UIKit's windows - each StateUI window in a
/// window scene iOS connected - and the core woken on UIKit's main queue.
/// Design: docs/design/platforms/uikit/runtime.md
@MainActor
final class UIKitRenderer {
    static var log = HostLog(host: "UIKit")

    /// The one runtime of the process, which every scene iOS connects shows a window of.
    static let shared = UIKitRenderer()

    /// Where the application's pictures are.
    static var resourceDirectory: URL?

    let frameClock: UIKitFrameClock

    /// Whether the user asked for less motion.
    let reducesMotion: () -> Bool

    /// Whether each window has a scene of its own, which the host asks iOS for and lets go with the window; a host
    /// under test stands its windows in the one scene it has, which stays.
    var ownsScenes = true

    private(set) lazy var runtime = HostRuntime(
        clock: frameClock, reducesMotion: reducesMotion,
        makeNative: { [unowned self] element in UIKitElement(element, host: self) },
        log: { UIKitRenderer.log.error($0) }, views: { UIKitElement.liveViewCount })

    /// Every StateUI window with the controller showing it.
    let roster = WindowRoster<UIKitWindowController>()

    /// Where kept values stand between launches.
    let preferences: UserDefaults

    /// What the application stands on - the theme, the locale, the battery, the network - as UIKit tells it.
    private(set) lazy var environment = UIKitEnvironment(core: runtime.core)

    /// UIKit's part of the acts every host performs, and the host layer's performer of them.
    private(set) lazy var actToolkit = UIKitActToolkit(renderer: self)
    private(set) lazy var acts = HostActPerformer(
        toolkit: actToolkit, answers: runtime.core, tree: { [unowned self] in runtime.tree },
        answered: { [unowned self] in runtime.pump.turn() })

    /// The key a scene's session keeps its window's record under, for iOS to hand back as it restores the scene.
    static let recordKey = "StateUI.Window"

    /// The scenes iOS connected that no StateUI window stands in yet, each as the window it came in as.
    let restored = RestoredWindows<UIWindowScene>()

    /// What each StateUI scene keeps, by its key, for the records of its windows.
    var sceneValues = SceneValues()

    /// Whether iOS connected the scene the application launched in.
    private var launched = false

    private var started = false

    /// The menu bar as it was last built.
    private var menuBarSaid = ""

    init(
        clock: (() -> Double)? = nil, preferences: UserDefaults = .standard,
        reducesMotion: @escaping () -> Bool = { UIAccessibility.isReduceMotionEnabled }
    ) {
        frameClock = clock.map { UIKitFrameClock(now: $0, ticksWithTheDisplay: false) } ?? UIKitFrameClock()
        self.preferences = preferences
        self.reducesMotion = reducesMotion
        runtime.displayCycle.presenter = self
        runtime.pump.presenter = self
        // Nothing renders before iOS connects the first scene: a window it kept opens its StateUI scene with what
        // that kept.
        runtime.pump.waitsForFirstWindow = true
        // On iOS the focus moves between the fields and editors the user types in, which say so.
        for name in [
            UITextField.textDidBeginEditingNotification, UITextField.textDidEndEditingNotification,
            UITextView.textDidBeginEditingNotification, UITextView.textDidEndEditingNotification,
        ] {
            NotificationCenter.default.addObserver(self, selector: #selector(focusMoved), name: name, object: nil)
        }
    }

    /// The focus moved: every element following it hears where it is.
    @objc func focusMoved() {
        runtime.tree.root?.uiKit.reportFocus()
    }

    /// Starts the runtime as the application launches: what the host realizes and what the device is, then the core
    /// woken on the main queue whenever it has work.
    func start() {
        guard !started else { return }
        started = true
        runtime.core.setRealization(UIKitRegistrations.registry.realization, unrealized: UIKitRealization.unrealized)
        reportEnvironment()
        environment.start(reportingChanges: { [weak self] report in self?.runtime.environmentChanged(report) })
        hydratePersistentState()
        runtime.tree.followTheLanguagesDirection()
        let core = runtime.core
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            core.ringForever { DispatchQueue.main.async { self?.runtime.pump.turn() } }
        }
    }

    /// Asks iOS for a scene for a window the tree holds and no scene stands for - on an iPad another window.
    private func requestScene() {
        UIApplication.shared.activateSceneSession(
            for: UISceneSessionActivationRequest(role: .windowApplication), errorHandler: { error in
                MainActor.assumeIsolated { Self.log.error("no scene for another window: \(error.localizedDescription)") }
            })
    }

    /// A scene's lifecycle moved: the window standing in it is in front of the user and activated, off the screen
    /// once in the background, and neither between.
    func scene(_ scene: UIWindowScene, movedTo phase: ApplicationPhase) {
        guard let shown = roster.windows.first(where: { $0.1.window?.windowScene === scene })?.0 else { return }
        window(shown, movedTo: Self.standing(in: scene, moved: phase))
    }

    /// Where a window stands for the user in `scene`, moved to `phase`: iPadOS keeps every window on screen active
    /// and dims those behind the one the user works in, which stand inactive.
    /// Design: docs/design/platforms/uikit/runtime.md#scenes
    private static func standing(in scene: UIWindowScene, moved phase: ApplicationPhase) -> ApplicationPhase {
        phase == .active && scene.traitCollection.activeAppearance == .inactive ? .inactive : phase
    }

    /// The user came to the window in `scene` or went to another: it stands in front, or behind, where its scene is
    /// active.
    private func frontMoved(in scene: UIWindowScene) {
        guard scene.activationState == .foregroundActive else { return }
        self.scene(scene, movedTo: .active)
    }

    /// `window`'s lifecycle moved: the host layer settles what that means for it, its scene and the application.
    func window(_ window: MountedElement, movedTo phase: ApplicationPhase) {
        roster.windows.first { $0.0 === window }?.1.toldPhase = phase
        runtime.windowStateChanged(window, minimized: phase == .background, activated: phase == .active)
    }

    /// A window that came to stand in a scene already in front, or already behind, hears where it stands: its scene
    /// tells no move it made before the window stood in it.
    private func tellStandingPhases() {
        for (element, controller) in roster.windows where controller.toldPhase == nil {
            switch controller.window?.windowScene?.activationState {
            case .foregroundActive?:
                guard let scene = controller.window?.windowScene else { break }
                window(element, movedTo: Self.standing(in: scene, moved: .active))
            case .background?: window(element, movedTo: .background)
            default: break
            }
        }
    }

    /// The user closed the window standing in the scene `session` names - on an iPad, swiped it away.
    func closedByUser(_ session: UISceneSession) {
        guard let window = roster.windows.first(where: { $0.1.session === session })?.0 else { return }
        runtime.userClosed(window)
    }

    /// A scene iOS connected, which says what the display is and, the first, what theme the user chose: the window
    /// standing for its session comes back to it; else the window it kept comes in as its kind for its value; else a
    /// window the tree holds, waiting for the scene the host asked for, stands in it; else it is a new window.
    /// Design: docs/design/platforms/uikit/runtime.md#scenes
    func connect(_ scene: UIWindowScene) {
        environment.followTheme(of: scene)
        environment.reportDisplay(of: scene)
        let first = !launched
        launched = true

        if let standing = roster.windows.first(where: { $0.1.holds(scene.session) })?.1 {
            standing.stand(in: scene)
            return synchronizeWindows()
        }
        let kept = (scene.session.userInfo?[Self.recordKey] as? String).flatMap(WindowRecord.init)
        if let kept, restored.accept(kept, native: scene, values: &sceneValues, in: runtime) {
            return runtime.pump.turn()
        }
        if !first, let waiting = roster.windows.first(where: { $0.1.session == nil })?.1 {
            waiting.stand(in: scene)
            return synchronizeWindows()
        }
        // The first is the window launch opens; any other, one more of the group with no name. A kept window no
        // scene declares now is a new one: iOS connected its scene, and the user is to see something in it.
        let new = WindowRecord(identifier: scene.session.persistentIdentifier)
        _ = restored.accept(new, native: scene, values: &sceneValues, in: runtime)
        runtime.pump.turn()
    }

    /// A scene iOS let go of - in the background, to come back - takes its window with it; the StateUI window
    /// stands until its session comes back or the user closes it.
    func disconnect(_ scene: UIWindowScene) {
        roster.windows.first { $0.1.window?.windowScene === scene }?.1.sceneLeft()
    }

    /// A scene keeps a value: every window of it writes it in its session's record, for whichever comes back first.
    func keepSceneValue(_ call: HostActCall) {
        guard sceneValues.keep(call.arguments) != nil else { return }
        keepRecords()
    }

    /// Writes each window's record in its scene's session: its kind, its value and what its StateUI scene keeps.
    private func keepRecords() {
        for (element, controller) in roster.windows {
            let scene = element.enclosing(type: .scene).map(SceneValues.key(of:)) ?? ""
            controller.keep { WindowRecord(of: element, identifier: $0, kept: sceneValues[scene]) }
        }
    }

    private func reportEnvironment() {
        let device = UIDevice.current
        #if targetEnvironment(simulator)
        let deviceType = DeviceType.virtual
        #else
        let deviceType = DeviceType.physical
        #endif
        runtime.core.setDeviceInfo(HostDeviceInfo(
            formFactor: device.userInterfaceIdiom == .pad ? .tablet : .phone, platform: "iOS", model: device.model,
            manufacturer: "Apple", name: device.name, versionString: device.systemVersion, deviceType: deviceType))
        let bundle = Bundle.main
        runtime.core.setApplicationInfo(HostApplicationInfo(
            name: bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ?? ProcessInfo.processInfo.processName,
            packageName: bundle.bundleIdentifier ?? "",
            versionString: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
            buildString: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""))
    }

    /// Shows every StateUI window in a window scene of its own, the first waiting one; a window the tree no longer
    /// holds lets its scene go.
    func synchronizeWindows() {
        guard let root = runtime.tree.root, root.type == .application else { return }

        sceneValues.keep(only: Set(SceneValues.scenes(of: root).map(SceneValues.key(of:))))
        roster.update(root: root, make: { [unowned self] element in
            let scene = restored.take(for: element)?.native
            if scene == nil, ownsScenes, launched { requestScene() }
            let controller = UIKitWindowController(element, scene: scene)
            controller.onFrontMoved = { [weak self] scene in self?.frontMoved(in: scene) }
            return controller
        }, close: { [unowned self] closing in
            guard ownsScenes else { return closing.hide() }
            bringBack(insteadOf: closing, staying: root.windows)
            closing.close()
        })
        for (element, controller) in roster.windows {
            controller.present(element, in: runtime)
        }
        keepRecords()
        tellStandingPhases()
        rebuildMenuBarWhereItChanged()
        runtime.displayCycle.hold()
    }

    /// A window closing in front of the user leaves the one they were in before in front of them - iPadOS shows the
    /// home screen once the scene in front goes.
    /// Design: docs/design/platforms/uikit/runtime.md#scenes
    private func bringBack(insteadOf closing: UIKitWindowController, staying: [MountedElement]) {
        guard let state = closing.window?.windowScene?.activationState,
              state == .foregroundActive || state == .foregroundInactive,
              let back = runtime.lifecycle.activatedLast(among: staying) ?? staying.first,
              let session = roster.windows.first(where: { $0.0 === back })?.1.session
        else { return }
        UIApplication.shared.activateSceneSession(
            for: UISceneSessionActivationRequest(session: session), errorHandler: { error in
                MainActor.assumeIsolated { Self.log.error("no window to come back to: \(error.localizedDescription)") }
            })
    }

    /// The menus the user's window's page puts on the application's menu bar, as the host layer composes them.
    var pageMenus: [MenuEntry] {
        roster.windows.first { $0.1.window === userWindow }?.1.pageMenus ?? []
    }

    /// Those menus as UIKit's main menu takes them, each under an identifier of its own.
    var menuBar: [UIMenu] {
        pageMenus.enumerated().map { index, menu in
            UIKitMenus.menu(
                menu.entries, title: menu.title,
                identifier: UIMenu.Identifier("stateui.menu.\(menu.standard?.description ?? String(index))"))
        }
    }

    /// Asks UIKit to build its main menu again where the page's menus say something else now or stand for other
    /// elements: an entry standing in another's place with the same words answers another element.
    /// Design: docs/design/platforms/uikit/pages.md#menus
    private func rebuildMenuBarWhereItChanged() {
        let said = UIKitMenus.said(menuBar, identified: true)
        guard said != menuBarSaid else { return }
        menuBarSaid = said
        UIMenuSystem.main.setNeedsRebuild()
    }

    /// The window the user is looking at: the key one, else the first.
    var userWindow: UIWindow? {
        roster.windows.first { $0.1.window?.isKeyWindow == true }?.1.window ?? roster.windows.first?.1.window
    }

    /// A picture the application ships, by its name: its own file, else its drawing (`PictureArithmetic.drawnFiles`),
    /// each at the pixels a point it holds - read from exactly that file, as UIKit's own reading of a path would take
    /// a `@3x` file beside it for it. No name asks for no picture.
    static func image(named name: String) -> UIImage? {
        guard !name.isEmpty else { return nil }
        for drawn in PictureArithmetic.drawnFiles(for: name) {
            guard let path = resourceDirectory?.appendingPathComponent(drawn.file).path,
                  let data = FileManager.default.contents(atPath: path),
                  let image = UIImage(data: data, scale: CGFloat(drawn.scale))
            else { continue }
            // Named by the name it was asked for, which reads it back.
            image.accessibilityIdentifier = name
            return image
        }
        log.error("no picture named \(name) in the application's images")
        return nil
    }

    /// The picture `name` as a bar or a tab shows it: `height` points tall and as wide as its shape makes it
    /// (`PictureArithmetic.glyph`) - its own pixels, drawn smaller.
    /// Design: docs/design/platforms/uikit/pages.md#pictures-on-the-bars
    static func glyph(named name: String, height: Double) -> UIImage? {
        guard let image = image(named: name) else { return nil }
        guard let pixels = image.cgImage, image.size.height > 0 else { return image }
        let size = PictureArithmetic.glyph(
            LayoutSize(width: image.size.width, height: image.size.height), height: height)
        let glyph = UIImage(
            cgImage: pixels, scale: image.scale * image.size.height / size.height, orientation: image.imageOrientation)
            .withRenderingMode(image.renderingMode)
        glyph.accessibilityIdentifier = name
        return glyph
    }
}

extension UIKitRenderer: TurnPresenter {
    func presentRendered() {
        synchronizeWindows()
    }

    func perform(_ call: HostActCall) {
        acts.perform(call)
    }
}

extension UIKitRenderer: FramePresenter {
    var wantsFrames: Bool {
        runtime.frames.wantsFrames
    }

    func commitUserReports(now: Double) {
        runtime.frames.commit(now: now)
    }

    func present(states: [Int32: HostStateValue], properties: [UInt64: Set<Prop>]) {
        let impact = runtime.tree.present(states: states, properties: properties)
        if impact.windowChrome { synchronizeWindows() }
    }

    func renderIfNeeded() {
        if runtime.core.needsRender { runtime.pump.turn() }
    }
}
#endif
