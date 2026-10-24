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
        // Words on a bar the tree paints - its title and its actions: the color written, else light on a dark one
        // and dark on a light one (`BandWords`).
        let foreground = BandWords.color(on: chrome.background, written: chrome.foreground)?.argb
        // The bar's own theme: dark for light words on a dark bar.
        let theme: ColorScheme = chrome.background.flatMap(BandWords.light(on:)).map { $0 ? .dark : .light } ?? .system
        // A declared title area stands in the title's place, as an application names itself on WinUI's title bar.
        let area = chrome.titleArea
        let icon = WinUIStrings.lines(WinUIPictures.lines(area?.icon))
        let title = area?.title ?? (chrome.showsTitle ? chrome.title : "")
        stateui_winui_title_bar_set(
            handle, title, area?.subtitle ?? "", icon, chrome.back != nil,
            chrome.sidebarToggle != nil, background != nil, background ?? 0, foreground != nil, foreground ?? 0,
            theme.rawValue)

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
                        let spelled = actions.map { $0.shortcut.flatMap(WinUIKeys.spelled) ?? (key: 0, modifiers: 0) }
                        stateui_winui_title_bar_set_actions(
                            handle, titles, identifiers, icons, actions.map(\.showsWords), actions.map(\.isDestructive),
                            places, leading, actions.map(\.isEnabled), spelled.map(\.key), spelled.map(\.modifiers),
                            actions.map { $0.shortcut.map(KeyboardShortcuts.givesWayToTyping) ?? false },
                            actions.map { $0.isOn.map { $0 ? 1 : 0 } ?? -1 }, Int32(actions.count))
                    }
                }
            }
            drawnPlaces = places
            drawnLeading = leading
            showMenus(of: actions, places: places)
        }
        drawn = actions
        menuActions = Self.menus(of: actions, places: places).flatMap { $0.menu.actions }

        if previous.center !== chrome.center { stateui_winui_title_bar_set_title_view(handle, chrome.center?.handle) }
    }

    /// The menus the actions' buttons open, each with its action's place, whether it is held, and its items told from
    /// where the items of those before it end: on the bar, its menu - held where it splits or is held, as a command
    /// bar's button has no arrow part; behind "more", what it offers there, its click opening it.
    /// Design: docs/design/platforms/winui/pages.md#the-windows-chrome
    private static func menus(
        of actions: [WinUIToolbarAction], places: [Int32]
    ) -> [(place: Int32, held: Bool, first: Int32, menu: WinUIMenu)] {
        var first: Int32 = 0
        return zip(actions.indices, actions).compactMap { place, action in
            guard let opened = action.menu else { return nil }
            let behind = places[place] < 0
            let menu = WinUIMenu(entries: behind ? opened.inOverflow : opened.entries)
            defer { first += Int32(menu.actions.count) }
            return (Int32(place), !behind && opened.opening != .click, first, menu)
        }
    }

    /// Gives each action's button holding a menu its menu.
    private func showMenus(of actions: [WinUIToolbarAction], places: [Int32]) {
        for (place, held, first, menu) in Self.menus(of: actions, places: places) {
            menu.relayed {
                stateui_winui_title_bar_set_action_menu(handle, place, held, first, $0, $1, $2, $3, $4, $5, $6, $7, $8, $9)
            }
        }
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
        drawn = []
        drawnPlaces = []
        drawnLeading = 0
    }
}
