// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A view a page scrolls by - a ScrollView's, an ItemsView's: kept clear of the bars over it, telling where it
/// stands and the farthest it stands, in points, as that changes. Design: docs/design/host/layout.md#a-bar-at-the-foot
@MainActor
protocol AndroidPageScroller: AnyObject {
    func keepClear(_ clearance: Clearance)

    var standing: (offset: Point, reach: Point) { get }

    var standingChanged: (() -> Void)? { get set }
}

extension AndroidScrollView: AndroidPageScroller {}
