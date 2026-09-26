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
    let window: UIWindow?

    private let root = UIKitRootViewController()
    private let presentation = WindowPresentation()

    init(_ element: MountedElement, scene: UIWindowScene?) {
        guard let scene else {
            window = nil
            return
        }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = root
        window.makeKeyAndVisible()
        self.window = window
    }

    /// Shows what the window holds now: the arrangement of pages it shows, and the title of the page the user
    /// sees.
    func present(_ element: MountedElement, in runtime: HostRuntime) {
        let changes = presentation.show(element, in: runtime.lifecycle)
        if let (_, arrangement) = changes.arrangement {
            root.show(arrangement?.uiKit.view)
        }
        let title = presentation.arrangement?.visiblePage?.value(.title)?.string
        window?.windowScene?.title = title.flatMap { $0.isEmpty ? nil : $0 } ?? element.value(.title)?.string
    }

    /// The tree let the window go: its scene goes with it.
    func close() {
        let session = window?.windowScene?.session
        hide()
        guard let session else { return }
        UIApplication.shared.requestSceneSessionDestruction(session, options: nil)
    }

    /// Takes the window out of its scene, which stays.
    func hide() {
        window?.isHidden = true
        window?.windowScene = nil
    }
}

/// The view a scene's window shows: the window's arrangement of pages within the safe area.
@MainActor
final class UIKitRootViewController: UIViewController {
    private var page: UIView?

    override func loadView() {
        view = UIView()
        view.backgroundColor = .systemBackground
    }

    /// Shows `page` in place of the one before.
    func show(_ page: UIView?) {
        guard page !== self.page else { return }
        self.page?.removeFromSuperview()
        self.page = page
        if let page { view.addSubview(page) }
        view.setNeedsLayout()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        page?.frame = view.bounds.inset(by: view.safeAreaInsets)
    }
}
#endif
