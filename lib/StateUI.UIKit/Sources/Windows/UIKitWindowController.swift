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

    /// The session of the scene the window stands in, which the user closes the window by.
    private(set) var session: UISceneSession?

    /// The phase the window was last told; nil until it was told one.
    var toldPhase: ApplicationPhase?

    private let root = UIKitRootViewController()
    let presentation = WindowPresentation()

    init(_ element: MountedElement, scene: UIWindowScene?) {
        if let scene { stand(in: scene) }
    }

    /// Stands the window in `scene`, which iOS connected for it.
    func stand(in scene: UIWindowScene) {
        guard window == nil else { return }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = root
        window.makeKeyAndVisible()
        self.window = window
        session = scene.session
    }

    /// Shows what the window holds now: the arrangement of pages it shows, and the title of the page the user
    /// sees.
    func present(_ element: MountedElement, in runtime: HostRuntime) {
        let changes = presentation.show(element, in: runtime.lifecycle)
        if let (_, arrangement) = changes.arrangement {
            root.show(arrangement?.uiKit.controller)
        }
        if let overlay = changes.overlay {
            root.lay(overlay?.uiKit.view)
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
        let title = presentation.arrangement?.visiblePage?.value(.title)?.string
        window?.windowScene?.title = title.flatMap { $0.isEmpty ? nil : $0 } ?? element.value(.title)?.string
    }

    /// The menus of the page the user sees - the top sheet's, else the arrangement's - as UIKit's main menu takes
    /// them, each under an identifier of its own.
    var pageMenus: [UIMenu] {
        let page = (presentation.sheets.last ?? presentation.arrangement)?.visiblePage
        let menus = page?.children.first { $0.type == .menuBar }.map(MenuEntry.menus(of:)) ?? []
        return menus.enumerated().map { index, menu in
            UIKitMenus.menu(menu.entries, title: menu.title, identifier: UIMenu.Identifier("stateui.menu.\(index)"))
        }
    }

    /// The tree let the window go: its scene goes with it.
    func close() {
        let session = window?.windowScene?.session
        hide()
        guard let session else { return }
        UIApplication.shared.requestSceneSessionDestruction(session, options: nil)
    }

    /// Takes the window out of its scene, which stays: its sheets go first, heard by nobody - the tree that asked for
    /// them is gone.
    func hide() {
        root.letGo()
        window?.isHidden = true
        window?.windowScene = nil
    }
}

/// What a scene's window shows: the controller of the window's arrangement of pages, over the whole window - each
/// page stands within the safe area its bars leave - an overlay laid over it, and the pages presented over it as
/// sheets, each over the one before.
/// Design: docs/design/platforms/uikit/pages.md#sheets
@MainActor
final class UIKitRootViewController: UIViewController, UIAdaptivePresentationControllerDelegate {
    private var shown: UIViewController?
    private var overlay: UIView?

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

    /// Lays `overlay` over the arrangement, within the safe area, in place of the one before.
    func lay(_ overlay: UIView?) {
        guard overlay !== self.overlay else { return }
        self.overlay?.removeFromSuperview()
        self.overlay = overlay
        if let overlay { view.addSubview(overlay) }
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
        overlay?.frame = view.bounds.inset(by: view.safeAreaInsets)
    }
}
#endif
