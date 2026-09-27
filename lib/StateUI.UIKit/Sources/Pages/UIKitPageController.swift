// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A page as UIKit's controllers hold it: its view standing within the safe area the bars leave, its bar item what
/// the page says of its bar.
/// Design: docs/design/platforms/uikit/pages.md
@MainActor
final class UIKitPageController: UIViewController {
    /// The page's element, which stands its view.
    private weak var page: UIKitElement?

    init(page: UIKitElement) {
        self.page = page
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("UIKitPageController is made in code")
    }

    override func loadView() {
        view = UIView()
        view.backgroundColor = .systemBackground
        if let shown = page?.view { view.addSubview(shown) }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let room = view.bounds.inset(by: view.safeAreaInsets)
        page?.placedFrame = Rect(x: room.minX, y: room.minY, width: room.width, height: room.height)
        page?.view?.layoutIfNeeded()
    }
}
#endif
