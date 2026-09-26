// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A NavigationStack: its top page across its whole frame. The pages below are kept by their elements and held by
/// no view, so each keeps what it showed for when the user comes back to it. The stack's furniture - the top page's
/// title, the way back and the page's actions - is the window's chrome, which the window composes from the visible
/// arrangement, so WinUI is given no second navigation model to reconcile with StateUI's path.
/// Design: docs/design/platforms/winui/pages.md#a-navigation-stack
@MainActor
final class WinUINavigationView: WinUILayoutView {
    override func heldViews() -> [WinUIView] {
        items.last.map { [$0.view] } ?? []
    }

    override func contentSize(width: Double?) -> LayoutSize {
        SingleChildArithmetic.size(of: items.last, padding: Insets(0), width: width)
    }

    override func arrange(in bounds: Rect) {
        guard let page = items.last else { return }
        page.view.layout(SingleChildArithmetic.place(of: page, in: bounds, padding: Insets(0), direction: direction))
    }
}
