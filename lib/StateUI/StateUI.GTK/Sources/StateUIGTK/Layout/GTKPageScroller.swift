// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A view a page scrolls by - a ScrollView's, an ItemsView's: where it stands and the farthest it stands, told as
/// that changes, so a bottom bar beside the page follows its rows. Design: docs/design/host/layout.md#a-bar-at-the-foot
@MainActor
protocol GTKPageScroller: AnyObject {
    var standing: (offset: Point, reach: Point) { get }

    var standingChanged: (() -> Void)? { get set }
}

extension GTKScrollView: GTKPageScroller {}
