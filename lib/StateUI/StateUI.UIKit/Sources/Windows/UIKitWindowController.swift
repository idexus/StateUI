// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// One StateUI window in a window scene of its own: its arrangement of pages in the scene's window, within the safe
/// area, its title the scene's, as the host layer presents a window (`WindowPresentation`).
/// Design: docs/design/platforms/uikit/runtime.md#scenes
@MainActor
final class UIKitWindowController {
    /// The scene's window; nil for a StateUI window no scene stands for yet.
    private(set) var window: UIWindow?

    /// What the window shows behind its pages, as its element last said; nil for UIKit's own.
    private var background: UIColor?

    /// The session of the scene the window stands in, which the user closes the window by.
    private(set) var session: UISceneSession?

    /// The phase the window was last told; nil until it was told one.
    var toldPhase: ApplicationPhase?

    /// The record its session keeps, for iOS to hand back as it restores the scene.
    private(set) var record: WindowRecord?

    /// What the window does as the user comes to it or goes to another: iPadOS keeps every window on screen active
    /// and dims those the user is not in, which their scene's active appearance tells.
    var onFrontMoved: ((UIWindowScene) -> Void)?

    /// The scene's active appearance followed, while the window stands in it.
    private var frontWatch: (scene: UIWindowScene, registration: UITraitChangeRegistration)?

    private let root = UIKitRootViewController()
    let presentation = WindowPresentation()

    init(_ element: MountedElement, scene: UIWindowScene?) {
        if let scene { stand(in: scene) }
    }

    /// Whether the window stands for the scene session `session`.
    func holds(_ session: UISceneSession) -> Bool {
        self.session?.persistentIdentifier == session.persistentIdentifier
    }

    /// Writes the record `make` makes of the window, given its session's identity, in the session - where it
    /// changed.
    func keep(_ make: (String) -> WindowRecord) {
        guard let session else { return }
        let record = make(session.persistentIdentifier)
        guard record != self.record else { return }
        self.record = record
        session.userInfo = (session.userInfo ?? [:]).merging([UIKitRenderer.recordKey: record.text]) { $1 }
    }

    /// iOS let the scene go, and its window with it; the session stays, for the scene to come back.
    func sceneLeft() {
        stopWatchingFront()
        window?.isHidden = true
        window?.rootViewController = nil
        window = nil
    }

    /// Stands the window in `scene`, which iOS connected for it.
    func stand(in scene: UIWindowScene) {
        guard window == nil else { return }
        let window = UIWindow(windowScene: scene)
        window.backgroundColor = background
        window.overrideUserInterfaceStyle = UIKitActToolkit.style(HostThemes.held)
        window.rootViewController = root
        window.makeKeyAndVisible()
        self.window = window
        session = scene.session
        let registration = scene.registerForTraitChanges([UITraitActiveAppearance.self]) {
            [weak self] (scene: UIWindowScene, _: UITraitCollection) in
            self?.onFrontMoved?(scene)
        }
        frontWatch = (scene, registration)
    }

    /// Stops following the scene's active appearance, as the window leaves it.
    private func stopWatchingFront() {
        guard let frontWatch else { return }
        frontWatch.scene.unregisterForTraitChanges(frontWatch.registration)
        self.frontWatch = nil
    }

    /// Has every page under `controller` show its background again - the window's, where it paints none of its
    /// own.
    private static func showBackgrounds(under controller: UIViewController?) {
        guard let controller else { return }
        (controller as? UIKitPageController)?.showBackground()
        for child in controller.children { showBackgrounds(under: child) }
        showBackgrounds(under: controller.presentedViewController)
    }

    /// Shows what the window holds now: the arrangement of pages it shows, and the title of the page the user
    /// sees.
    func present(_ element: MountedElement, in runtime: HostRuntime) {
        let changes = presentation.show(element, in: runtime.lifecycle)
        if let traits = changes.traits {
            background = traits.background.painted.flatMap(UIColor.init(stateUI:))
            window?.backgroundColor = background
        }
        if let (_, arrangement) = changes.arrangement {
            root.show(arrangement?.uiKit.controller)
        }
        if let overlays = changes.overlays {
            root.lay(overlays.compactMap(\.uiKit.view))
        }
        if let sheets = changes.sheets {
            root.onSheetDismissed = { [weak runtime, weak element] remaining in
                guard let runtime, let element else { return }
                runtime.goBack(.dismissSheet(remaining: remaining), in: element)
            }
            root.present(sheets.compactMap(\.uiKit.controller), animated: !runtime.reducesMotion())
        }
        presentation.arrangement?.uiKit.composeChrome()
        presentation.sheets.forEach { $0.uiKit.composeChrome() }
        let title = presentation.arrangement?.titledPage?.value(.title)?.string
        window?.windowScene?.title = title.flatMap { $0.isEmpty ? nil : $0 } ?? element.value(.title)?.string
        // Every page shows the window's background where it paints none of its own, the arrangement in place.
        if changes.traits != nil { Self.showBackgrounds(under: window?.rootViewController) }
    }

    /// The menus of the page the user sees - the top sheet's, else the arrangement's - as the host layer composes
    /// them from its path.
    var pageMenus: [MenuEntry] {
        (presentation.sheets.last ?? presentation.arrangement)?.visiblePage?.chromeMenus.menus ?? []
    }

    /// The tree let the window go: its scene goes with it.
    func close() {
        let session = window?.windowScene?.session
        hide()
        guard let session else { return }
        UIApplication.shared.requestSceneSessionDestruction(session, options: nil)
    }

    /// Takes the window out of its scene, which stays: its sheets go with it, heard by nobody - the tree that asked
    /// for them is gone.
    func hide() {
        stopWatchingFront()
        root.letGo()
        window?.isHidden = true
        window?.windowScene = nil
    }
}

/// What a scene's window shows: the controller of the window's arrangement of pages, over the whole window - each
/// page stands within the safe area its bars leave - the overlays laid over it, and the pages presented over it as
/// sheets, each over the one before.
/// Design: docs/design/platforms/uikit/pages.md#sheets
@MainActor
final class UIKitRootViewController: UIViewController, UIAdaptivePresentationControllerDelegate {
    private var shown: UIViewController?
    private var overlays: [UIView] = []

    /// The sheets shown, the first presented by this controller, each next by the one before.
    private var sheets: [UIViewController] = []

    /// What the window does when the user took the top sheet away, handed how many stay.
    var onSheetDismissed: ((Int) -> Void)?

    /// The sheets asked for before the window stood on screen, which UIKit presents over it only once it does.
    private var waiting: (sheets: [UIViewController], animated: Bool)?
    private var appeared = false

    override func loadView() {
        view = UIView()
        view.backgroundColor = .systemBackground
    }

    /// Shows `arrangement` in place of the one before.
    func show(_ arrangement: UIViewController?) {
        guard arrangement !== shown else { return }
        if let shown {
            shown.willMove(toParent: nil)
            shown.view.removeFromSuperview()
            shown.removeFromParent()
        }
        shown = arrangement
        guard let arrangement else { return }
        addChild(arrangement)
        arrangement.view.frame = view.bounds
        arrangement.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.insertSubview(arrangement.view, at: 0)
        arrangement.didMove(toParent: self)
    }

    /// Lays `overlays` over the arrangement, the first lowest, within the safe area, in place of those before.
    func lay(_ overlays: [UIView]) {
        guard !overlays.elementsEqual(self.overlays, by: ===) else { return }
        for leaving in self.overlays where !overlays.contains(where: { $0 === leaving }) { leaving.removeFromSuperview() }
        self.overlays = overlays
        for overlay in overlays { view.addSubview(overlay) }
        view.setNeedsLayout()
    }

    /// Presents `sheets` over the arrangement: those shown and still asked for stay, the rest go from the top, and
    /// each new one comes over the one before once that one stands - UIKit presents over a controller only then.
    func present(_ sheets: [UIViewController], animated: Bool) {
        guard appeared else { return waiting = (sheets, animated) }
        var common = 0
        while common < self.sheets.count, common < sheets.count, self.sheets[common] === sheets[common] { common += 1 }
        let coming = Array(sheets[common...])
        guard common < self.sheets.count else { return presentEach(coming, animated: animated) }
        let presenter = common == 0 ? self : self.sheets[common - 1]
        self.sheets = Array(self.sheets.prefix(common))
        presenter.dismiss(animated: animated && coming.isEmpty) { [weak self] in
            self?.presentEach(coming, animated: animated)
        }
    }

    private func presentEach(_ coming: [UIViewController], animated: Bool) {
        guard let sheet = coming.first else { return }
        let presenter = sheets.last ?? self
        sheet.modalPresentationStyle = .pageSheet
        sheet.presentationController?.delegate = self
        sheets.append(sheet)
        presenter.present(sheet, animated: animated && coming.count == 1) { [weak self] in
            self?.presentEach(Array(coming.dropFirst()), animated: animated)
        }
    }

    /// Tells nobody of its sheets any more: they leave with the window.
    func letGo() {
        onSheetDismissed = nil
        sheets = []
        waiting = nil
    }

    /// The user took the top sheet away - swiped it down: the window hears how many stay.
    func presentationControllerDidDismiss(_ presentation: UIPresentationController) {
        guard let index = sheets.firstIndex(where: { $0 === presentation.presentedViewController }) else { return }
        sheets.removeSubrange(index...)
        onSheetDismissed?(index)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        appeared = true
        if let (sheets, animated) = waiting {
            waiting = nil
            present(sheets, animated: animated)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        for overlay in overlays { overlay.frame = view.bounds.inset(by: view.safeAreaInsets) }
    }
}
#endif
