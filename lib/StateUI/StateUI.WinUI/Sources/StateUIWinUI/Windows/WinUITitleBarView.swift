// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIWinUI

/// The one chrome of a StateUI window: WinUI's `TitleBar`. WinUI owns placement, overflow, the caption buttons and
/// dragging the window; StateUI owns what stands on it - its way back and sidebar toggle as the bar's own buttons,
/// an action as a button of the command bar at its edge, a title view attached as it is.
/// Design: docs/design/platforms/winui/pages.md#the-windows-chrome
@MainActor
final class WinUITitleBarView: WinUIView {
    /// The chrome the bar shows, as it was last composed.
    private(set) var chrome = WinUIWindowChrome()

    /// The actions on the bar.
    private var actions = WinUIBarActions(bar: .titleBar)

    /// The actions as they were last drawn, in reading order, those behind "more" last.
    var drawn: [WinUIToolbarAction] { actions.drawn }

    init() {
        super.init { number in stateui_winui_title_bar_make(number) }
    }

    /// Shows `chrome`, writing only the parts that changed.
    func apply(_ chrome: WinUIWindowChrome) {
        let previous = self.chrome
        self.chrome = chrome

        // The bar's material: a color, or the in-app acrylic for a blur.
        let ground = WinUIGround(chrome.material)
        // Words on a bar the tree paints - its title and its actions: the color written, else light on a dark one
        // and dark on a light one (`BandWords`).
        let foreground = BandWords.color(on: chrome.background, written: chrome.foreground)?.argb
        // The bar's own theme: dark for light words on a dark bar.
        let theme: ColorScheme = chrome.background.flatMap(BandWords.light(on:)).map { $0 ? .dark : .light } ?? .system
        // A title area stands in the title's place, as an application names itself on WinUI's title bar; else the
        // page's title and the line under it.
        let area = chrome.titleArea
        let icon = WinUIStrings.lines(WinUIPictures.lines(area?.icon))
        let title = area?.title ?? (chrome.showsTitle ? chrome.title : "")
        let line = area.map(\.subtitle) ?? (chrome.showsTitle ? chrome.subtitle : nil)
        stateui_winui_title_bar_set(
            handle, title, line ?? "", icon, chrome.back != nil, chrome.sidebarToggle != nil, ground.kind, ground.argb,
            ground.opacity, ground.tintOpacity, foreground != nil, foreground ?? 0, theme.rawValue)

        menuActions = actions.show(
            leading: chrome.leading, trailing: chrome.trailing, overflow: chrome.overflow, on: handle)

        if previous.center !== chrome.center { stateui_winui_title_bar_set_title_view(handle, chrome.center?.handle) }
    }

    /// A key went down in the window, before the element holding the focus has it: whether a view took it.
    func takesKey(key: Int32, modifiers: Int32) -> Bool {
        WinUIKeys.shortcut(key: key, modifiers: modifiers).map { chrome.takeKey?($0) == true } ?? false
    }

    /// The user pressed the way back (-1), the sidebar's toggle (-2), Escape (-3), or an action by its place.
    override func chose(_ index: Int) {
        switch index {
        case -1: if let sheet = chrome.sheet { sheet.back() } else { chrome.back?.perform() }
        case -2: chrome.sidebarToggle?()
        case -3: if chrome.escape?() != true { chrome.sheet?.dismiss() }
        default: if drawn.indices.contains(index), drawn[index].isEnabled { drawn[index].perform() }
        }
    }

    override func detach() {
        super.detach()
        chrome = WinUIWindowChrome()
        actions = WinUIBarActions(bar: .titleBar)
    }
}
