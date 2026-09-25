// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIWinUI

/// WinUI's `NavigationView`: the sidebar page in its pane - beside the detail page where the window is wide, over it
/// where it is narrow - and a row across the top of the detail. WinUI chooses which, as it does for any Windows app.
/// Design: docs/design/platforms/winui/pages.md#a-split-view
@MainActor
final class WinUISidebarView: WinUIView {
    /// The width from which the pane stands beside the detail, in DIPs: where WinUI's navigation pane expands.
    static let expandsAt = 1008.0

    /// What the view does when its pane opens or closes of WinUI's accord.
    var onPresented: ((Bool) -> Void)?

    init() {
        super.init { number in stateui_winui_split_make(number, Self.expandsAt) }
    }

    /// The two pages, the row over the detail, whether the pane is open, and how wide it opens.
    func set(sidebar: WinUIView?, detail: WinUIView?, row: WinUIView?, open: Bool, paneWidth: Double) {
        stateui_winui_split_set(handle, sidebar?.handle, detail?.handle, row?.handle, open, paneWidth)
    }

    override func presented(_ open: Bool) {
        guard !ProgramWrite.isWriting else { return }
        onPresented?(open)
    }

    override func detach() {
        onPresented = nil
    }
}
