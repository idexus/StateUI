// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A page's bottom bar in its room - a window's, a sheet's, a split view's pane: the bar's view at the room's foot over
/// the page, as tall as it lays out across the safe area (`BottomBarPlace`).
/// Design: docs/design/host/layout.md#a-bar-at-the-foot
@MainActor
final class AppKitBottomBarView: AppKitSingleChildView {
    /// Shows `bar` - the visible page's bottom bar - in place of what it showed; nil for none.
    func show(_ bar: MountedElement?) {
        setItem(bar?.appKit.layoutItem)
    }

    /// Stands the bar at `place`; nowhere for none.
    func stand(at place: BottomBarPlace?) {
        frame = place.map { NSRect(placed: $0.bar) } ?? .zero
    }

    /// Where the bar stands at the foot of `safe` in `whole`, as tall as it lays out across it; nil where it shows
    /// nothing.
    func place(safe: Rect, whole: Rect) -> BottomBarPlace? {
        guard let item, item.isShown else { return nil }
        return BottomBarPlace(height: Double(fittingContentSize(width: safe.width).height), safe: safe, whole: whole)
    }
}

#endif
