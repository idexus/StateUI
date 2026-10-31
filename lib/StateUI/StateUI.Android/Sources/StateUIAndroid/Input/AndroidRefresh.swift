// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIAndroid

/// A view the user pulls to refresh: a scroller, a list.
@MainActor
protocol AndroidRefreshing: AnyObject {
    /// Hears the user's pull; answers whether its spinner stays.
    var onRefreshPulled: (() -> Bool)? { get set }

    var refresh: AndroidRefresh? { get }
}

/// The pull to refresh around a scroller or a list: AndroidX's swipe to refresh in the relay's `StateUIRefresh`,
/// enabled while the pull is offered and spinning while the element says it refreshes.
/// Design: docs/design/platforms/android/layout.md#the-pull-to-refresh
@MainActor
final class AndroidRefresh {
    let layout: JavaObject

    /// A pull to refresh telling the host a pull as the view numbered `number`'s.
    init(number: Int64) {
        layout = Java.new(JavaAPI.refresh, JavaAPI.newRefresh, .object(AndroidRenderer.context), .long(number))
    }

    /// The pull offered, or not, and its spinner showing as the element says.
    func apply<Realized>(_ values: ElementValues<Realized>) {
        Java.call(layout.reference, JavaAPI.setEnabled, .bool(values[RefreshElementContract.isRefreshEnabled] ?? false))
        let refreshing = values[RefreshElementContract.isRefreshing] ?? false
        guard Java.callBool(layout.reference, JavaAPI.isRefreshing) != refreshing else { return }
        Java.call(layout.reference, JavaAPI.setRefreshing, .bool(refreshing))
    }
}
