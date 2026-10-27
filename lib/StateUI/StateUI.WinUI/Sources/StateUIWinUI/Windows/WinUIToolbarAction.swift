// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// One action a window's chrome performs for the arrangement it shows.
@MainActor
struct WinUIToolbarAction {
    let title: String
    let isEnabled: Bool
    var identifier: String?
    /// The files its picture may stand in, in order (`PictureArithmetic.files`); none for words alone.
    var icon: [String] = []
    var isDestructive = false
    /// Whether its words stand beside its picture (`MountedElement.showsActionWords`).
    var showsWords = true
    /// The keys pressing it while its window is in front; nil for none.
    var shortcut: KeyboardShortcut?
    /// The mount of the toolbar item it stands for; none for the way back.
    var mount: UInt64?
    let perform: () -> Void
    /// A setting's state - its button a two-state one, checked while on; nil for an action.
    var isOn: Bool? = nil
    /// The menu its button opens; nil for an action holding none.
    var menu: WinUIToolbarMenu? = nil
    /// Whether it stands in a lone item's own group, not one its author declared (`ToolbarGroupContract.standsAlone`).
    var standsAlone = true

    /// Whether two actions draw the same button. What an action performs is taken again on every composition.
    func draws(like other: WinUIToolbarAction) -> Bool {
        title == other.title && isEnabled == other.isEnabled && identifier == other.identifier && icon == other.icon
            && isDestructive == other.isDestructive && showsWords == other.showsWords && shortcut == other.shortcut
            && isOn == other.isOn && menu?.said == other.menu?.said && standsAlone == other.standsAlone
    }
}

/// The menu a bar's button opens: how it opens, whether an arrow says its click opens it, its entries, and what it
/// offers behind the bar's "more" (`ButtonMenu`).
@MainActor
struct WinUIToolbarMenu {
    let opening: ButtonMenuOpening
    var showsArrow = true
    let entries: [MenuEntry]
    let inOverflow: [MenuEntry]

    /// Everything the menu shows: a bar draws its buttons again where it says something else.
    struct Said: Equatable {
        let opening: ButtonMenuOpening
        let showsArrow: Bool
        let entries: [MenuEntry.Said]
        let inOverflow: [MenuEntry.Said]
    }

    var said: Said {
        Said(opening: opening, showsArrow: showsArrow, entries: entries.map(\.said), inOverflow: inOverflow.map(\.said))
    }

    /// The control a button holding this menu stands as on the bar, as the relay numbers it: WinUI's bar button for
    /// a click without an arrow and for a held menu, a split button for a split, a drop-down button for a click with
    /// its arrow; behind "more", the bar's button.
    func standing(behind: Bool) -> Int32 {
        guard !behind else { return 0 }
        switch opening {
        case .arrow: return 1
        case .click where showsArrow: return 2
        default: return 0
        }
    }
}
