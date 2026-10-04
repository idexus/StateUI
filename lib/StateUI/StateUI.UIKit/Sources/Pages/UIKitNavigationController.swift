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
final class UIKitNavigationController: UINavigationController, UINavigationControllerDelegate {
    /// What the stack does when the user took its top pages away, handed how many stay.
    var onPopped: ((Int) -> Void)?

    /// The pages as the tree last gave them.
    private var pages: [UIViewController] = []

    /// Whether each page shows the bar, as it says.
    var showsBar: (UIViewController) -> Bool = { _ in true }

    init() {
        super.init(nibName: nil, bundle: nil)
        delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("UIKitNavigationController is made in code")
    }

    /// Shows `pages`, the last on top: moving there as a push or a pop where one page came or went.
    func setPages(_ pages: [UIViewController], animated: Bool) {
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
        let moved = abs(pages.count - viewControllers.count) == 1
            && zip(pages, viewControllers).allSatisfy { $0 === $1 }
        self.pages = pages
        setViewControllers(pages, animated: animated && moved && view.window != nil)
    }

    /// Shows the bar or hides it, as the page on top says.
    func showTopsBar() {
        let hidden = !(viewControllers.last.map(showsBar) ?? true)
        if hidden != isNavigationBarHidden { setNavigationBarHidden(hidden, animated: false) }
    }

    func navigationController(
        _ navigation: UINavigationController, willShow shown: UIViewController, animated: Bool
    ) {
        setNavigationBarHidden(!showsBar(shown), animated: animated)
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
