// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// One action a window's toolbar performs for the arrangement it shows.
@MainActor
struct AppKitToolbarAction {
    let identifier: NSToolbarItem.Identifier
    let title: String
    let image: NSImage?
    let isEnabled: Bool
    let perform: () -> Void
    /// A setting's state, on or off; nil for an action.
    var isOn: Bool? = nil
    /// Whether the item stands out on the bar: a setting on that shows no picture of its own for it.
    var standsOut = false
    /// The menu it opens; nil for an action holding none.
    var menu: AppKitToolbarMenu? = nil

    /// Whether two actions draw the same toolbar item. What an action
    /// performs is taken again on every composition.
    func draws(like other: AppKitToolbarAction) -> Bool {
        identifier == other.identifier
            && title == other.title
            && image === other.image
            && isEnabled == other.isEnabled
            && isOn == other.isOn
            && standsOut == other.standsOut
            && menu?.said == other.menu?.said
    }
}

/// The menu a toolbar's button opens: how it opens, whether its arrow shows, its entries, and what it offers behind
/// the toolbar's overflow (`ButtonMenu`).
@MainActor
struct AppKitToolbarMenu {
    let opening: ButtonMenuOpening
    let showsArrow: Bool
    let entries: [MenuEntry]
    let inOverflow: [MenuEntry]

    /// Everything the menu shows: a toolbar keeps its item while it says the same.
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

/// What a window's toolbar shows.
///
/// The window controller composes it from the visible arrangement, and the
/// toolbar lays it out in one order: the sidebar toggle and the separator
/// that tracks the sidebar, the way back, the page's title where a painted
/// band hides the system's, the leading groups of actions, the center, the
/// trailing groups, native overflow and the button closing a sheet. A space
/// stands between two groups, and before the overflow, so each keeps a
/// background of its own.
@MainActor
struct AppKitWindowChrome {
    var sidebar: NSSplitViewController?
    /// Whether the sidebar's toggle stands at the toolbar's start; the sidebar's part stays apart without it.
    var showsSidebarToggle = true
    var back: AppKitToolbarAction?
    var title: NSView?
    var leadingActions: [[AppKitToolbarAction]] = []
    var center: NSView?
    var actions: [[AppKitToolbarAction]] = []
    var overflow: [AppKitToolbarAction] = []
    /// The button closing the sheet a stack's bar stands in, at the trailing edge.
    var close: AppKitToolbarAction?

    /// What the chrome's own controls say: the way back's glyph and the overflow.
    var words: ChromeWords
}

/// The one native toolbar of a StateUI window.
///
/// AppKit owns placement, overflow, the toolbar's material and window
/// dragging. StateUI owns what the items are: an action becomes a native
/// toolbar item, and a title view is attached as it is, so its identity and
/// state stay StateUI's.
@MainActor
final class AppKitWindowToolbar: NSObject, NSToolbarDelegate {
    static let back = NSToolbarItem.Identifier("StateUI.back")
    static let title = NSToolbarItem.Identifier("StateUI.title")
    static let center = NSToolbarItem.Identifier("StateUI.center")
    static let overflow = NSToolbarItem.Identifier("StateUI.overflow")
    static let close = NSToolbarItem.Identifier("StateUI.close")

    /// The system's own glyph for going back, saying `words`: one image for each.
    static func backImage(saying words: String) -> NSImage? {
        if let made = backImages[words] { return made }
        let made = NSImage(systemSymbolName: "chevron.backward", accessibilityDescription: words)
        backImages[words] = made
        return made
    }

    private static var backImages: [String: NSImage] = [:]

    let toolbar: NSToolbar

    private var identifiers: [NSToolbarItem.Identifier] = []
    private weak var sidebar: NSSplitViewController?
    private var views: [NSToolbarItem.Identifier: NSView] = [:]
    private var actions: [NSToolbarItem.Identifier: AppKitToolbarAction] = [:]
    private var overflowActions: [AppKitToolbarAction] = []
    /// The menu each item opening one shows, kept so its entries stand in one menu across compositions.
    private var menus: [NSToolbarItem.Identifier: NSMenu] = [:]
    private var words: ChromeWords?

    /// The chrome last shown, shown again as a slot comes to hold something or nothing.
    private var shown: AppKitWindowChrome?

    /// The slots the layouts standing in the toolbar are held in, by the layout.
    private var slots: [ObjectIdentifier: AppKitToolbarSlot] = [:]

    init(windowIdentifier: String) {
        toolbar = NSToolbar(identifier: NSToolbar.Identifier(
            "StateUI.Window.\(windowIdentifier)"))
        super.init()

        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = false
    }

    /// Shows exactly this chrome. Items that stay keep their native item and
    /// view; only what changed is written.
    func apply(_ chrome: AppKitWindowChrome) {
        shown = chrome
        var nextSlots: [ObjectIdentifier: AppKitToolbarSlot] = [:]
        /// A layout stands in the toolbar in its slot, and not at all while it holds nothing.
        func standing(_ view: NSView?) -> NSView? {
            guard let view, view is AppKitTravelingLayout else { return view }
            let slot = slots[ObjectIdentifier(view)] ?? AppKitToolbarSlot(holding: view)
            slot.onEmptied = { [weak self] in
                guard let self, let shown = self.shown else { return }
                self.apply(shown)
            }
            nextSlots[ObjectIdentifier(view)] = slot
            return slot.holdsNothing ? nil : slot
        }
        let center = standing(chrome.center)
        slots = nextSlots

        var nextIdentifiers: [NSToolbarItem.Identifier] = []
        var nextViews: [NSToolbarItem.Identifier: NSView] = [:]
        var nextActions: [NSToolbarItem.Identifier: AppKitToolbarAction] = [:]

        if chrome.sidebar != nil {
            if chrome.showsSidebarToggle { nextIdentifiers.append(.toggleSidebar) }
            nextIdentifiers.append(.sidebarTrackingSeparator)
        }
        if let back = chrome.back {
            nextIdentifiers.append(Self.back)
            nextActions[Self.back] = back
        }
        if let title = chrome.title {
            nextIdentifiers.append(Self.title)
            nextViews[Self.title] = title
        }
        let place = { (groups: [[AppKitToolbarAction]]) in
            for (index, group) in groups.enumerated() {
                if index > 0 { nextIdentifiers.append(.space) }
                for action in group {
                    nextIdentifiers.append(action.identifier)
                    nextActions[action.identifier] = action
                }
            }
        }
        place(chrome.leadingActions)
        nextIdentifiers.append(.flexibleSpace)
        if let center {
            nextIdentifiers += [Self.center, .flexibleSpace]
            nextViews[Self.center] = center
        }
        place(chrome.actions)
        if !chrome.overflow.isEmpty {
            if !chrome.actions.isEmpty { nextIdentifiers.append(.space) }
            nextIdentifiers.append(Self.overflow)
        }
        if let close = chrome.close {
            nextIdentifiers.append(Self.close)
            nextActions[Self.close] = close
        }

        // An item opening a menu is another kind of toolbar item.
        let sameItems = nextIdentifiers == identifiers
            && nextActions.allSatisfy { (actions[$0.key]?.menu == nil) == ($0.value.menu == nil) }
            && chrome.sidebar === sidebar
            && nextViews.count == views.count
            && nextViews.allSatisfy { views[$0.key] === $0.value }
        let drawsAlike = nextActions.allSatisfy { identifier, action in
            actions[identifier].map { $0.draws(like: action) } ?? false
        }
            && chrome.overflow.count == overflowActions.count
            && zip(chrome.overflow, overflowActions).allSatisfy { $0.draws(like: $1) }
            && chrome.words == words

        identifiers = nextIdentifiers
        menus = menus.filter { nextActions[$0.key]?.menu != nil }
        sidebar = chrome.sidebar
        views = nextViews
        actions = nextActions
        overflowActions = chrome.overflow
        words = chrome.words
        toolbar.centeredItemIdentifiers = center == nil ? [] : [Self.center]

        if sameItems {
            if !drawsAlike { toolbar.items.forEach(configure) }
            return
        }

        while !toolbar.items.isEmpty {
            toolbar.removeItem(at: toolbar.items.count - 1)
        }
        for (index, identifier) in nextIdentifiers.enumerated() {
            toolbar.insertItem(withItemIdentifier: identifier, at: index)
        }
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        identifiers
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        identifiers + [.flexibleSpace, .space, .toggleSidebar, .sidebarTrackingSeparator]
    }

    /// The system's sidebar toggle toggles this window's split view, whoever
    /// holds the keyboard focus.
    func toolbarWillAddItem(_ notification: Notification) {
        guard let item = notification.userInfo?["item"] as? NSToolbarItem,
              item.itemIdentifier == .toggleSidebar
        else { return }

        item.target = sidebar
        item.action = #selector(NSSplitViewController.toggleSidebar(_:))
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        if itemIdentifier == .sidebarTrackingSeparator, let sidebar {
            return NSTrackingSeparatorToolbarItem(
                identifier: itemIdentifier,
                splitView: sidebar.splitView,
                dividerIndex: 0)
        }

        // A search field stands as the toolbar's own search item, which draws it as AppKit's rounded field: a
        // field the toolbar holds as a plain item's view stands there with no field drawn at all.
        // Design: docs/design/platforms/appkit/runtime.md#the-toolbar
        let item: NSToolbarItem = if itemIdentifier == Self.overflow || actions[itemIdentifier]?.menu != nil {
            NSMenuToolbarItem(itemIdentifier: itemIdentifier)
        } else if views[itemIdentifier] is NSSearchField {
            NSSearchToolbarItem(itemIdentifier: itemIdentifier)
        } else {
            NSToolbarItem(itemIdentifier: itemIdentifier)
        }
        // The ways out stay in sight on a crowded bar: the actions give way first.
        if itemIdentifier == Self.back || itemIdentifier == Self.close { item.visibilityPriority = .high }
        configure(item)
        return item
    }

    private func configure(_ item: NSToolbarItem) {
        let identifier = item.itemIdentifier

        if let view = views[identifier] {
            if let search = item as? NSSearchToolbarItem, let field = view as? NSSearchField {
                if search.searchField !== field { search.searchField = field }
            } else {
                item.view = view
            }
            return
        }

        if identifier == Self.overflow, let menuItem = item as? NSMenuToolbarItem {
            menuItem.image = NSImage(systemSymbolName: "ellipsis.circle", accessibilityDescription: words?.more)
            menuItem.label = words?.more ?? ""
            menuItem.showsIndicator = false
            menuItem.menu = overflowMenu()
            return
        }

        guard let action = actions[identifier] else { return }
        item.label = action.title
        item.paletteLabel = action.title
        item.toolTip = action.title
        item.image = action.image
        item.title = action.image == nil ? action.title : ""
        item.isBordered = true
        item.isNavigational = identifier == Self.back
        item.target = self
        item.action = #selector(performAction(_:))
        item.autovalidates = false
        item.isEnabled = action.isEnabled
        item.style = action.standsOut ? .prominent : .plain
        if let menu = action.menu, let menuItem = item as? NSMenuToolbarItem { show(menu, on: menuItem) }
        // A setting's state as AppKit holds it on an item: the menu item it shows as words alone or in the overflow.
        item.menuFormRepresentation = action.isOn.map { isOn in
            let form = NSMenuItem(title: action.title, action: #selector(performForm(_:)), keyEquivalent: "")
            form.target = self
            form.representedObject = identifier
            form.image = action.image
            form.state = isOn ? .on : .off
            form.isEnabled = action.isEnabled
            return form
        }
    }

    /// An item opening `menu`: its click opens it where the button has none of its own - an arrow saying so as the
    /// tree says - else AppKit's arrow beside the button opens it, or, with no arrow, the button held.
    /// Design: docs/design/platforms/appkit/runtime.md#the-toolbar
    private func show(_ menu: AppKitToolbarMenu, on item: NSMenuToolbarItem) {
        let shown = menus[item.itemIdentifier] ?? NSMenu()
        menus[item.itemIdentifier] = shown
        Self.fill(shown, with: AppKitMenus.items(menu.entries))
        item.menu = shown
        switch menu.opening {
        case .click:
            item.target = nil
            item.action = nil
            item.showsIndicator = menu.showsArrow
        case .arrow, .none: item.showsIndicator = true
        case .hold: item.showsIndicator = false
        }
    }

    /// `menu` holding `items` alone, each taken out of the menu it stood in before.
    private static func fill(_ menu: NSMenu, with items: [NSMenuItem]) {
        menu.autoenablesItems = false
        menu.removeAllItems()
        for item in items {
            item.menu?.removeItem(item)
            menu.addItem(item)
        }
    }

    /// The overflow's menu: each action an item, an action opening a menu a submenu under its words.
    private func overflowMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        for (index, action) in overflowActions.enumerated() {
            let item = NSMenuItem(
                title: action.title,
                action: #selector(performOverflow(_:)),
                keyEquivalent: "")
            item.target = self
            item.tag = index
            item.image = action.image
            item.isEnabled = action.isEnabled
            item.state = action.isOn == true ? .on : .off
            if let opened = action.menu {
                item.target = nil
                item.action = nil
                let submenu = NSMenu(title: action.title)
                Self.fill(submenu, with: AppKitMenus.items(opened.inOverflow))
                item.submenu = submenu
            }
            menu.addItem(item)
        }
        return menu
    }

    @objc private func performAction(_ sender: NSToolbarItem) {
        actions[sender.itemIdentifier]?.perform()
    }

    @objc private func performForm(_ sender: NSMenuItem) {
        (sender.representedObject as? NSToolbarItem.Identifier).flatMap { actions[$0] }?.perform()
    }

    @objc private func performOverflow(_ sender: NSMenuItem) {
        guard overflowActions.indices.contains(sender.tag) else { return }
        overflowActions[sender.tag].perform()
    }

    var identifiersForTesting: [NSToolbarItem.Identifier] { identifiers }
    var sidebarForTesting: NSSplitViewController? { sidebar }

    var actionTitlesForTesting: [String] {
        identifiers.compactMap { $0 == Self.back || $0 == Self.close ? nil : actions[$0]?.title }
    }

    var overflowTitlesForTesting: [String] { overflowActions.map(\.title) }

    /// The actions behind the overflow, each by its identifier and whether it can be chosen.
    var overflowForTesting: [(identifier: NSToolbarItem.Identifier, isEnabled: Bool)] {
        overflowActions.map { ($0.identifier, $0.isEnabled) }
    }

    func itemForTesting(_ identifier: NSToolbarItem.Identifier) -> NSToolbarItem? {
        toolbar.items.first { $0.itemIdentifier == identifier }
    }

    func itemForTesting(titled title: String) -> NSToolbarItem? {
        toolbar.items.first { $0.label == title && views[$0.itemIdentifier] == nil }
    }

    /// Chooses the action `identifier` as the user does - on the bar or in its overflow - where it can be chosen.
    func performForTesting(_ identifier: NSToolbarItem.Identifier) {
        guard let action = actions[identifier] ?? overflowActions.first(where: { $0.identifier == identifier }),
              action.isEnabled
        else { return }
        action.perform()
    }
}

/// The application's title area: its mark, name and the line under it,
/// standing at the trailing edge of the window's title bar in the system's
/// colors, or in the bar's foreground over a painted band.
@MainActor
final class AppKitTitleAreaView: NSStackView {
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let textStack = NSStackView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        orientation = .horizontal
        alignment = .centerY
        spacing = 6
        edgeInsets = NSEdgeInsets(top: 0, left: 8, bottom: 0, right: 14)

        iconView.imageScaling = .scaleProportionallyDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),
        ])

        titleLabel.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.lineBreakMode = .byTruncatingTail

        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 0
        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(subtitleLabel)

        addArrangedSubview(iconView)
        addArrangedSubview(textStack)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppKitTitleAreaView is created in code")
    }

    func apply(title: String, subtitle: String, image: NSImage?, foreground: NSColor?) {
        titleLabel.textColor = foreground ?? .labelColor
        subtitleLabel.textColor = foreground?.withAlphaComponent(0.8) ?? .secondaryLabelColor
        titleLabel.stringValue = title
        titleLabel.isHidden = title.isEmpty
        subtitleLabel.stringValue = subtitle
        subtitleLabel.isHidden = subtitle.isEmpty
        iconView.image = image
        iconView.isHidden = image == nil
    }

    var titleForTesting: String { titleLabel.stringValue }
    var subtitleForTesting: String { subtitleLabel.stringValue }
    var titleColorForTesting: NSColor? { titleLabel.textColor }
    var imageForTesting: NSImage? { iconView.image }
}
#endif
