// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A view the user pulls to refresh: a scroller, a list.
@MainActor
protocol UIKitRefreshing: AnyObject {
    /// Its pull to refresh.
    var refresh: UIKitRefresh { get }
}

/// The pull to refresh on a UIKit scroll view: UIKit's refresh control, there while the pull is offered and spinning
/// while the element says it refreshes; a pull told to `onPulled`, which answers whether the spinner stays.
/// Design: docs/design/platforms/uikit/input.md#the-pull-to-refresh
@MainActor
final class UIKitRefresh {
    /// Hears the user's pull; answers whether its spinner stays.
    var onPulled: (() -> Bool)?

    /// The scroll view it pulls.
    private(set) weak var scroller: UIScrollView?
    private var control: UIRefreshControl?

    init(_ scroller: UIScrollView) {
        self.scroller = scroller
    }

    /// The pull offered, or not, and its spinner showing as the element says.
    func apply<Realized>(_ values: ElementValues<Realized>) {
        let offered = values[RefreshElementContract.isRefreshEnabled] ?? false
        let refreshing = values[RefreshElementContract.isRefreshing] ?? false
        if offered, control == nil {
            let control = UIRefreshControl()
            control.addAction(UIAction { [weak self] _ in self?.pulled() }, for: .valueChanged)
            scroller?.refreshControl = control
            self.control = control
        } else if !offered, let control {
            control.endRefreshing()
            scroller?.refreshControl = nil
            self.control = nil
        }
        guard let control, control.isRefreshing != refreshing else { return }
        if refreshing { control.beginRefreshing() } else { control.endRefreshing() }
    }

    private func pulled() {
        if onPulled?() != true { control?.endRefreshing() }
    }
}
#endif
