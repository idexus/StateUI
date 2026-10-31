// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIWinUI

/// A page's bar at its foot (`.toolbar(.bottom)`): a row of WinUI's command bars beneath the page, its leading actions
/// at its start and the rest at its end, drawn as the title bar's are.
/// Design: docs/design/platforms/winui/pages.md#the-bar-at-the-foot
@MainActor
final class WinUIFootBarView: WinUIView {
    /// The actions on the bar.
    private var actions = WinUIBarActions(bar: .foot)

    /// The actions as they were last drawn, in reading order, those behind "more" last.
    var drawn: [WinUIToolbarAction] { actions.drawn }

    init() {
        super.init { number in stateui_winui_foot_bar_make(number) }
    }

    /// Shows `chosen`, drawing only what changed.
    func show(_ chosen: ChromeActions) {
        let action = WinUIWindowController.action
        menuActions = actions.show(
            leading: chosen.start.map { $0.map(action) }, trailing: chosen.end.map { $0.map(action) },
            overflow: chosen.overflow.map(action), on: handle)
        invalidateMeasure()
    }

    /// The user pressed an action, by its place.
    override func chose(_ index: Int) {
        if drawn.indices.contains(index), drawn[index].isEnabled { drawn[index].perform() }
    }

    override func detach() {
        super.detach()
        actions = WinUIBarActions(bar: .foot)
    }
}
