// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIWinUI

/// WinUI's `SplitView`: the sidebar page in its pane - beside the detail page or over it, as the split places it -
/// and the detail on a card, a row across its top.
/// Design: docs/design/platforms/winui/pages.md#a-split-view
@MainActor
final class WinUISidebarView: WinUIView {
    /// The width from which the pane stands beside the detail, in DIPs: where a Windows application's navigation
    /// pane expands.
    static let expandsAt = 1008.0

    /// What the view does when its pane opens or closes of WinUI's accord.
    var onPresented: ((Bool) -> Void)?

    init() {
        super.init { number in stateui_winui_split_make(number) }
    }

    /// The two pages, the row over the detail, whether the pane is open, and whether it stands beside the detail.
    func set(sidebar: WinUIView?, detail: WinUIView?, row: WinUIView?, open: Bool, beside: Bool) {
        stateui_winui_split_set(handle, sidebar?.handle, detail?.handle, row?.handle, open, beside)
    }

    /// The pane's whole width, in DIPs: the theme's, as WinUI opens it.
    var paneWidth: Double { stateui_winui_split_pane_width(handle) }

    /// Stands the pane `pane` DIPs wide on its way in or out, the sidebar at its whole `width`.
    func slide(pane: Double, width: Double) {
        stateui_winui_split_slide(handle, pane, width)
    }

    /// Asks WinUI to measure the pane and everything in it again: it applies an arrange inside the pane only to what
    /// it measured in that pass, so the sidebar's page follows a new height only measured again.
    /// Design: docs/design/platforms/winui/pages.md#a-split-view
    func measurePaneAgain() {
        stateui_winui_split_measure_pane_again(handle)
    }

    override func presented(_ open: Bool) {
        guard !ProgramWrite.isWriting else { return }
        onPresented?(open)
    }

    override func detach() {
        super.detach()
        onPresented = nil
    }
}
