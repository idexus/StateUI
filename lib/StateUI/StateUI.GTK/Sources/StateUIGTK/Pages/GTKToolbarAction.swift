// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// One action a page's header bar performs for the page.
@MainActor
struct GTKToolbarAction {
    /// The toolbar item the action stands for, which hears it chosen.
    weak var item: MountedElement?
    let title: String

    /// The picture the button shows; nil for the title alone.
    var icon: HostPicture? = nil

    /// Whether the title stands beside the picture.
    var showsTitle = false
    let isEnabled: Bool

    /// Whether the action destroys something: libadwaita's `destructive-action` colours its button.
    let isDestructive: Bool

    /// The action of `item` as its bar's button shows it, read as a menu's entry is (`MenuEntry`).
    init(_ item: MountedElement) {
        let entry = MenuEntry.entry(of: item)
        self.item = item
        title = entry.title
        icon = entry.icon
        showsTitle = item.showsActionWords
        isEnabled = entry.isEnabled
        isDestructive = entry.isDestructive
    }

    /// Tells the item it was chosen.
    func perform() {
        item?.gtk.choose()
    }

    /// Whether two actions draw the same button. The item an action stands for is taken again on every composition.
    func draws(like other: GTKToolbarAction) -> Bool {
        title == other.title && icon == other.icon && showsTitle == other.showsTitle && isEnabled == other.isEnabled
            && isDestructive == other.isDestructive
    }
}

/// What a page's header bar shows: the page's title and the line under it, or its title view, the groups of actions
/// at each edge, the overflow behind the bar's menu, whether the bar shows at all and whether it offers the way back
/// - and the tabs beneath it.
@MainActor
struct GTKPageChrome {
    var title = ""

    /// Whether the header bar shows the title; the window keeps it for the system all the same.
    var showsTitle = true

    /// The line under the title; nil for none.
    var subtitle: String?
    var titleView: GTKView?

    /// A tabbed view's switcher, which stands in a bar of its own beneath the header bar; nil for none.
    var tabs: GTKView?

    /// The groups of actions at the bar's start and at its end, each in reading order.
    var leading: [[GTKToolbarAction]] = []
    var trailing: [[GTKToolbarAction]] = []
    var overflow: [GTKToolbarAction] = []

    /// The menus the page's path declares, which stand in the bar's main menu; none for no main menu.
    var mainMenu: [MenuEntry] = []
    var showsBar = true
    var offersBack = true

    /// What the bar is painted in, and what stands on it in; nil for the platform's.
    var barBackground: HostValue?
    var barForeground: HostValue?

    /// The split view's sidebar, where this page's header bar offers its toggle - the detail's: whether it shows,
    /// and what turns it.
    var sidebar: (shows: Bool, toggle: () -> Void)?
}
