// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIWinUI

/// The actions a bar shows - the window's title bar's, a sheet's head's, or a split view's pane's - in reading order, each with its group's
/// place, the leading edge's first, or -1 behind "more"; drawn again only where they changed.
/// Design: docs/design/platforms/winui/pages.md#the-windows-chrome
@MainActor
struct WinUIBarActions {
    /// The bar the actions stand on.
    enum Bar {
        case titleBar, sheet, pane
    }

    let bar: Bar

    /// The actions as they were last drawn, in reading order, those behind "more" last.
    private(set) var drawn: [WinUIToolbarAction] = []
    private var drawnPlaces: [Int32] = []
    private var drawnLeading: Int32 = 0

    /// Draws `leading`, `trailing` and `overflow` on the bar `handle` where they differ from what it shows: what each
    /// entry of their menus does, in order (`WinUIView.menuActions`).
    mutating func show(
        leading: [[WinUIToolbarAction]], trailing: [[WinUIToolbarAction]], overflow: [WinUIToolbarAction],
        on handle: StateUIObjectRef
    ) -> [() -> Void] {
        let groups = leading + trailing
        let actions = groups.flatMap { $0 } + overflow
        let places = groups.enumerated().flatMap { place, group in group.map { _ in Int32(place) } }
            + overflow.map { _ in -1 }
        let leadingGroups = Int32(leading.count)
        if actions.count != drawn.count || places != drawnPlaces || leadingGroups != drawnLeading
            || !zip(actions, drawn).allSatisfy({ $0.draws(like: $1) }) {
            draw(actions, places: places, leading: leadingGroups, on: handle)
            drawnPlaces = places
            drawnLeading = leadingGroups
            showMenus(of: actions, places: places, on: handle)
        }
        drawn = actions
        return Self.menus(of: actions, places: places).flatMap { $0.menu.actions }
    }

    /// Writes `actions` on the bar through the relay.
    private func draw(_ actions: [WinUIToolbarAction], places: [Int32], leading: Int32, on handle: StateUIObjectRef) {
        let set = switch bar {
        case .titleBar: stateui_winui_title_bar_set_actions
        case .sheet: stateui_winui_sheet_set_actions
        case .pane: stateui_winui_split_set_actions
        }
        // Each button's place on a capsule, its group's on the bar; none behind "more".
        // Design: docs/design/platforms/winui/pages.md#a-bars-buttons
        let capsules = Dictionary(grouping: actions.indices.filter { places[$0] >= 0 }) { places[$0] }
            .reduce(into: [Int32](repeating: BarCapsule.none.rawValue, count: actions.count)) { capsules, group in
                let indices = group.value.sorted()
                let standing = BarCapsule.places(count: indices.count, standsAlone: actions[indices[0]].standsAlone)
                for (index, place) in zip(indices, standing) { capsules[index] = place.rawValue }
            }
        WinUIStrings.withCStrings(actions.map(\.title)) { titles in
            WinUIStrings.withCStrings(actions.map { $0.identifier ?? "" }) { identifiers in
                WinUIStrings.withCStrings(actions.map { WinUIStrings.lines($0.icon) }) { icons in
                    let spelled = actions.map { $0.shortcut.flatMap(WinUIKeys.spelled) ?? (key: 0, modifiers: 0) }
                    set(
                        handle, titles, identifiers, icons, actions.map(\.showsWords), actions.map(\.isDestructive),
                        places, leading, actions.map(\.isEnabled), spelled.map(\.key), spelled.map(\.modifiers),
                        actions.map { $0.shortcut.map(KeyboardShortcuts.givesWayToTyping) ?? false },
                        actions.map { $0.isOn.map { $0 ? 1 : 0 } ?? -1 },
                        zip(actions, places).map { action, place in action.menu?.standing(behind: place < 0) ?? 0 },
                        capsules, Int32(actions.count))
                }
            }
        }
    }

    /// The menus the actions' buttons open, each with its action's place, whether it is held, and its items told from
    /// where the items of those before it end: on the bar, its menu - a split button's arrow's, a click's, or held;
    /// behind "more", what it offers there, its click opening it.
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
            return (Int32(place), !behind && opened.opening == .hold, first, menu)
        }
    }

    /// Gives each action's button holding a menu its menu.
    private func showMenus(of actions: [WinUIToolbarAction], places: [Int32], on handle: StateUIObjectRef) {
        let set = switch bar {
        case .titleBar: stateui_winui_title_bar_set_action_menu
        case .sheet: stateui_winui_sheet_set_action_menu
        case .pane: stateui_winui_split_set_action_menu
        }
        for (place, held, first, menu) in Self.menus(of: actions, places: places) {
            menu.relayed { set(handle, place, held, first, $0, $1, $2, $3, $4, $5, $6, $7, $8, $9) }
        }
    }
}
