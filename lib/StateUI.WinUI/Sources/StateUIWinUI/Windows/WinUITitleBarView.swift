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

    /// The actions as they were last drawn, in reading order, those behind "more" last; each one's group's place.
    private(set) var drawn: [WinUIToolbarAction] = []
    private var drawnPlaces: [Int32] = []
    private var drawnLeading: Int32 = 0

    init() {
        super.init { number in stateui_winui_title_bar_make(number) }
    }

    /// Shows `chrome`, writing only the parts that changed.
    func apply(_ chrome: WinUIWindowChrome) {
        let previous = self.chrome
        self.chrome = chrome

        let background = chrome.background?.argb
        // Words on a bar the tree paints - its title and its actions: the colour written, else light on a dark one
        // and dark on a light one (`BandWords`).
        let foreground = BandWords.color(on: chrome.background, written: chrome.foreground)?.argb
        let light = chrome.background.flatMap(BandWords.light(on:))
        // A declared title area stands in the title's place, as an application names itself on WinUI's title bar.
        let area = chrome.titleArea
        let icon = WinUIStrings.lines(area?.icon.map(PictureArithmetic.files(for:)) ?? [])
        stateui_winui_title_bar_set(
            handle, area?.title ?? chrome.title, area?.subtitle ?? "", icon, chrome.back != nil,
            chrome.sidebarToggle != nil, background != nil, background ?? 0, foreground != nil, foreground ?? 0,
            light.map { $0 ? 1 : 2 } ?? 0)

        // Every action in reading order, each with its group's place - the leading edge's first - or -1 behind "more".
        let groups = chrome.leading + chrome.trailing
        let actions = groups.flatMap { $0 } + chrome.overflow
        let places = groups.enumerated().flatMap { place, group in group.map { _ in Int32(place) } }
            + chrome.overflow.map { _ in -1 }
        let leading = Int32(chrome.leading.count)
        if actions.count != drawn.count || places != drawnPlaces || leading != drawnLeading
            || !zip(actions, drawn).allSatisfy({ $0.draws(like: $1) }) {
            WinUIStrings.withCStrings(actions.map(\.title)) { titles in
                WinUIStrings.withCStrings(actions.map { $0.identifier ?? "" }) { identifiers in
                    WinUIStrings.withCStrings(actions.map { WinUIStrings.lines($0.icon) }) { icons in
                        stateui_winui_title_bar_set_actions(
                            handle, titles, identifiers, icons, actions.map(\.showsWords), actions.map(\.isDestructive),
                            places, leading, actions.map(\.isEnabled), Int32(actions.count))
                    }
                }
            }
            drawnPlaces = places
            drawnLeading = leading
        }
        drawn = actions

        if previous.center !== chrome.center { stateui_winui_title_bar_set_title_view(handle, chrome.center?.handle) }
    }

    /// The user pressed the way back (-1), the sidebar's toggle (-2), or an action by its place.
    override func chose(_ index: Int) {
        switch index {
        case -1: if let sheet = chrome.sheet { sheet.back() } else { chrome.back?.perform() }
        case -2: chrome.sidebarToggle?()
        case -3: chrome.sheet?.dismiss()
        default: if drawn.indices.contains(index), drawn[index].isEnabled { drawn[index].perform() }
        }
    }

    override func detach() {
        super.detach()
        chrome = WinUIWindowChrome()
        drawn = []
        drawnPlaces = []
        drawnLeading = 0
    }
}
