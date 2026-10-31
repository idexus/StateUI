// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A view a page scrolls by - a ScrollView's, an ItemsView's - kept clear of the bars over it.
/// Design: docs/design/host/layout.md#a-bar-at-the-foot
@MainActor
protocol AppKitPageScroller: AnyObject {
    /// Keeps `clearance` clear of what stands over it.
    func keepClear(_ clearance: Clearance)

    /// Where it stands and the farthest it stands, counted from its first content kept clear.
    var standing: (offset: Point, reach: Point) { get }

    /// What runs as where it stands, or how far it reaches, changes.
    var standingChanged: (() -> Void)? { get set }
}

extension AppKitScrollView: AppKitPageScroller {}
#endif
