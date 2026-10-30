// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A NavigationStack: UIKit's own navigation controller over its pages, its bar the top page's. The user taking
/// pages away - the back button, the edge swipe, the back button's menu - is told as how many stay.
/// Design: docs/design/platforms/uikit/pages.md#a-navigation-stack
@MainActor
final class UIKitNavigationController: UINavigationController, UINavigationControllerDelegate, UIKitSheetStanding {
    /// What runs once the controller has left the screen, as a sheet (`UIKitSheetStanding`).
    var leftScreen: (() -> Void)?

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        leftScreen?()
    }

    /// What the stack does when the user took its top pages away, handed how many stay.
    var onPopped: ((Int) -> Void)?

    /// The pages as the tree last gave them.
    private var pages: [UIViewController] = []

    /// Whether each page shows the bar, as it says.
    var showsBar: (UIViewController) -> Bool = { _ in true }

    /// What runs as the bar takes another width - laid out the first time, the device turned, the window resized.
    var onBarResized: (() -> Void)?
    private var barWidth: CGFloat = 0

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard navigationBar.bounds.width != barWidth else { return }
        barWidth = navigationBar.bounds.width
        onBarResized?()
    }

    /// The size of the background of the bar `page` stands under: the bar's width, from the top of the stack's view -
    /// under the status bar - to the bar's bottom edge; nothing before the bar is laid out.
    /// Design: docs/design/platforms/uikit/pages.md#the-bar
    static func barBackground(of page: UIViewController) -> CGSize {
        guard let bar = page.navigationController?.navigationBar else { return .zero }
        return CGSize(width: bar.bounds.width, height: bar.frame.maxY)
    }

    init() {
        super.init(nibName: nil, bundle: nil)
        delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("UIKitNavigationController is made in code")
    }

    /// Shows `pages`, the last on top: moving there as a push or a pop as the host layer says (`PathChange`).
    /// Design: docs/design/host/pages.md#a-path-that-changes
    func setPages(_ pages: [UIViewController], reducingMotion: Bool) {
        defer { showTopsBar() }
        // The user is taking pages away and the tree hears it once the move ends: a render meanwhile still
        // describes them, and showing them again would undo the user's way back.
        if transitionCoordinator != nil, pages.elementsEqual(self.pages, by: ===), viewControllers.count < pages.count,
           viewControllers.elementsEqual(pages.prefix(viewControllers.count), by: ===) {
            return
        }
        guard !pages.elementsEqual(self.pages, by: ===) || !viewControllers.elementsEqual(pages, by: ===) else {
            return
        }
        let change = PathChange.of(from: viewControllers, to: pages, same: ===)
        self.pages = pages
        let moves = (change?.moves(reducingMotion: reducingMotion) ?? false) && view.window != nil
        setViewControllers(pages, animated: moves)
        // Shown without a move, the page stands laid out at once: a move begun in the same turn - the sidebar's
        // slide - carries it from its place, where laying it out within that move would grow it from nothing.
        if !moves { view.layoutIfNeeded() }
    }

    /// Shows the bar or hides it, as the page on top says, and the toolbar while the page holds items for it.
    func showTopsBar() {
        let hidden = !(viewControllers.last.map(showsBar) ?? true)
        if hidden != isNavigationBarHidden { setNavigationBarHidden(hidden, animated: false) }
        let bare = Self.holdsNoToolbarItems(viewControllers.last)
        if bare != isToolbarHidden { setToolbarHidden(bare, animated: false) }
    }

    /// Whether `page` holds nothing for the toolbar.
    private static func holdsNoToolbarItems(_ page: UIViewController?) -> Bool {
        page?.toolbarItems?.isEmpty ?? true
    }

    func navigationController(
        _ navigation: UINavigationController, willShow shown: UIViewController, animated: Bool
    ) {
        setNavigationBarHidden(!showsBar(shown), animated: animated)
        setToolbarHidden(Self.holdsNoToolbarItems(shown), animated: animated)
    }

    func navigationController(
        _ navigation: UINavigationController, didShow shown: UIViewController, animated: Bool
    ) {
        let staying = viewControllers.count
        guard staying < pages.count, viewControllers.elementsEqual(pages.prefix(staying), by: ===) else { return }
        pages = viewControllers
        onPopped?(staying)
    }
}
#endif
