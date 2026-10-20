// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIWinUI

/// A NavigationStack: its top page across its whole frame. The pages below are kept by their elements and held by
/// no view, so each keeps what it showed for when the user comes back to it. The stack's furniture - the top page's
/// title, the way back and the page's actions - is the window's chrome, which the window composes from the visible
/// arrangement, so WinUI is given no second navigation model to reconcile with StateUI's path.
/// Design: docs/design/platforms/winui/pages.md#a-navigation-stack
@MainActor
final class WinUINavigationView: WinUILayoutView {
    /// Whether the user asked for less motion.
    private let reducesMotion: () -> Bool

    init(reducesMotion: @escaping () -> Bool) {
        self.reducesMotion = reducesMotion
        super.init()
    }

    /// The pages, the top one entering as the host layer says the path changed (`PathChange`): a page pushed from
    /// the end, one popped back to from the start, WinUI's own entrance; any other change with none.
    /// Design: docs/design/host/pages.md#a-path-that-changes
    @discardableResult
    override func setItems(_ items: [WinUILayoutItem]) -> Bool {
        let change = PathChange.of(from: self.items.map(\.view), to: items.map(\.view), same: ===)
        let moves = change?.moves(reducingMotion: reducesMotion()) ?? false
        stateui_winui_panel_set_entrance(handle, !moves ? 0 : change == .push ? Self.entrance : -Self.entrance)
        return super.setItems(items)
    }

    /// How far across a page enters from, in DIPs: WinUI's page slide.
    private static let entrance = 28.0

    override func heldViews() -> [WinUIView] {
        items.last.map { [$0.view] } ?? []
    }

    override func contentSize(width: Double?) -> LayoutSize {
        SingleChildArithmetic.size(of: items.last, width: width)
    }

    override func arrange(in bounds: Rect) {
        guard let page = items.last else { return }
        page.view.layout(SingleChildArithmetic.place(of: page, in: bounds, direction: direction))
    }
}
