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

    /// Whether two actions draw the same button. What an action performs is taken again on every composition.
    func draws(like other: WinUIToolbarAction) -> Bool {
        title == other.title && isEnabled == other.isEnabled && identifier == other.identifier && icon == other.icon
            && isDestructive == other.isDestructive && showsWords == other.showsWords && shortcut == other.shortcut
            && isOn == other.isOn && menu?.said == other.menu?.said
    }
}

/// The menu a bar's button opens: how it opens, its entries, and what it offers behind the bar's "more"
/// (`ButtonMenu`).
@MainActor
struct WinUIToolbarMenu {
    let opening: ButtonMenuOpening
    let entries: [MenuEntry]
    let inOverflow: [MenuEntry]

    /// Everything the menu shows: a bar draws its buttons again where it says something else.
    struct Said: Equatable {
        let opening: ButtonMenuOpening
        let entries: [MenuEntry.Said]
        let inOverflow: [MenuEntry.Said]
    }

    var said: Said { Said(opening: opening, entries: entries.map(\.said), inOverflow: inOverflow.map(\.said)) }
}
