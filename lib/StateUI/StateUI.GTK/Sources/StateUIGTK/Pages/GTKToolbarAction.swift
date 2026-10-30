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

    /// Whether the action destroys something: libadwaita's `destructive-action` colors its button.
    let isDestructive: Bool
    /// A setting's state - its button a toggle button, pressed in while on; nil for an action.
    let isOn: Bool?

    /// The menu its button opens; nil for an action holding none.
    let menu: GTKToolbarMenu?

    /// Whether it is words nobody chooses (`ToolbarLabel`): a label on the bar, an entry nobody can choose behind its
    /// More.
    let isLabel: Bool

    /// The action of `item` as its bar's button shows it, read as a menu's entry is (`MenuEntry`).
    init(_ item: MountedElement) {
        let entry = MenuEntry.entry(of: item)
        self.item = item
        title = entry.title
        icon = entry.icon
        showsTitle = item.showsActionWords
        isEnabled = entry.isEnabled
        isDestructive = entry.isDestructive
        isOn = item.type == .toolbarToggle ? entry.isOn == true : nil
        isLabel = item.type == .toolbarLabel
        let opening = ButtonMenu.opening(of: item)
        menu = opening == .none ? nil : GTKToolbarMenu(
            opening: opening, showsArrow: ButtonMenu.showsArrow(item), entries: ButtonMenu.entries(of: item),
            inOverflow: ButtonMenu.inOverflow(item))
    }

    /// Tells the item it was chosen.
    func perform() {
        item?.gtk.choose()
    }

    /// Whether two actions draw the same button. The item an action stands for is taken again on every composition.
    func draws(like other: GTKToolbarAction) -> Bool {
        title == other.title && icon == other.icon && showsTitle == other.showsTitle && isEnabled == other.isEnabled
            && isDestructive == other.isDestructive && isOn == other.isOn && menu?.said == other.menu?.said
            && isLabel == other.isLabel
    }
}

/// The menu a bar's button opens: how it opens, whether its arrow shows, its entries, and what it offers behind the
/// bar's overflow (`ButtonMenu`).
@MainActor
struct GTKToolbarMenu {
    let opening: ButtonMenuOpening
    let showsArrow: Bool
    let entries: [MenuEntry]
    let inOverflow: [MenuEntry]

    /// Everything the menu shows: a bar keeps its button while it says the same.
    struct Said: Equatable {
        let opening: ButtonMenuOpening
        let showsArrow: Bool
        let entries: [MenuEntry.Said]
        let inOverflow: [MenuEntry.Said]
    }

    var said: Said {
        Said(
            opening: opening, showsArrow: showsArrow, entries: entries.map(\.said), inOverflow: inOverflow.map(\.said))
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

    /// The page's bottom bar, beneath its content; nil for none.
    var bottomBar: GTKView?

    /// The edge the bottom bar shows while rows go on past it, and the page's scroller whose rows it follows.
    var bottomBarEdge = ScrollEdge.automatic
    var bottomBarScroller: GTKPageScroller?

    /// The groups of actions at the bar's start and at its end, each in reading order.
    var leading: [[GTKToolbarAction]] = []
    var trailing: [[GTKToolbarAction]] = []
    var overflow: [GTKToolbarAction] = []

    /// The actions of the bar at the page's foot (`.toolbar(.bottom)`), as the header bar's stand.
    var foot = GTKFootActions()

    /// The menus the page's path declares, which stand in the bar's main menu; none for no main menu.
    var mainMenu: [MenuEntry] = []
    var showsBar = true
    var offersBack = true
    var offersClose = true

    /// What the bar is painted in, and what stands on it in; nil for the platform's.
    var barBackground: HostValue?
    var barForeground: HostValue?

    /// The split view's sidebar, where this page's header bar offers its toggle - the detail's: whether it shows,
    /// and what turns it.
    var sidebar: (shows: Bool, toggle: () -> Void)?
}

/// The actions of a page's bar at its foot: its groups at its start and at its end, and those behind its More.
@MainActor
struct GTKFootActions {
    var leading: [[GTKToolbarAction]] = []
    var trailing: [[GTKToolbarAction]] = []
    var overflow: [GTKToolbarAction] = []

    /// Whether it holds no action.
    var isEmpty: Bool { leading.isEmpty && trailing.isEmpty && overflow.isEmpty }

    /// Whether it draws as `other` does.
    func draws(like other: GTKFootActions) -> Bool {
        let groups = { (one: [[GTKToolbarAction]], two: [[GTKToolbarAction]]) in
            one.count == two.count && zip(one, two).allSatisfy { pair in
                pair.0.count == pair.1.count && zip(pair.0, pair.1).allSatisfy { $0.draws(like: $1) }
            }
        }
        return groups(leading, other.leading) && groups(trailing, other.trailing) && groups([overflow], [other.overflow])
    }
}
