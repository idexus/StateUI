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
    /// Whether it is words nobody chooses (`ToolbarLabel`).
    var isLabel = false

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
            && isLabel == other.isLabel
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
/// toolbar lays it out in one order: the sidebar's part - its toggle, its
/// groups, its overflow - and the separator that tracks the sidebar, the way
/// back, the page's title where a painted band hides the system's, the
/// leading groups of actions, the center, the trailing groups, native overflow
/// and the button closing a sheet. A space stands between two groups, and
/// before the overflow, so each keeps a background of its own.
@MainActor
struct AppKitWindowChrome {
    var sidebar: NSSplitViewController?
    /// Whether the sidebar's toggle stands at the toolbar's start; the sidebar's part stays apart without it.
    var showsSidebarToggle = true
    /// The groups standing in the sidebar's part, at its start and at its end, and those behind its own overflow.
    var sidebarLeadingActions: [[AppKitToolbarAction]] = []
    var sidebarActions: [[AppKitToolbarAction]] = []
    var sidebarOverflow: [AppKitToolbarAction] = []

    /// How many groups stand in the sidebar's part.
    var sidebarGroups: Int { sidebarLeadingActions.count + sidebarActions.count }
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
    static let sidebarOverflow = NSToolbarItem.Identifier("StateUI.sidebarOverflow")
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
    /// What stands behind the bar's More, group by group, and behind the sidebar's part's.
    private var overflowGroups: [[AppKitToolbarAction]] = []
    private var overflowActions: [AppKitToolbarAction] { overflowGroups.flatMap { $0 } }
    private var sidebarOverflowGroups: [[AppKitToolbarAction]] = []
    private var sidebarOverflowActions: [AppKitToolbarAction] { sidebarOverflowGroups.flatMap { $0 } }

    /// The window the bar stands in, which a bar fitting itself measures in.
    weak var window: NSWindow?
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
    /// view; only what changed is written. A sheet's bar, ending with its close
    /// button, fits itself (`BarFit`): AppKit's own overflow would stand after it.
    /// The sidebar's part fits itself too: AppKit hides what it has no room for there, with no overflow of its own.
    /// Design: docs/design/platforms/appkit/runtime.md#sheets
    func apply(_ chrome: AppKitWindowChrome) {
        shown = chrome
        guard chrome.close != nil else { return layFittingTheSidebar(chrome) }
        let standing = BarFit.standing(groups: chrome.leadingActions.count + chrome.actions.count) { trial in
            lay(chrome, keeping: trial.groups)
            return fitsItsWindow
        }
        lay(chrome, keeping: standing.groups)
    }

    /// Fits the bar to its window again, as the window or its sidebar resizes.
    func fitAgain() {
        guard let shown, shown.close != nil || shown.sidebarGroups > 0 else { return }
        apply(shown)
    }

    /// `chrome` with its first `count` groups in reading order on the bar, the others behind More.
    private func lay(_ chrome: AppKitWindowChrome, keeping count: Int) {
        var kept = chrome
        kept.leadingActions = Array(chrome.leadingActions.prefix(count))
        kept.actions = Array(chrome.actions.prefix(max(0, count - chrome.leadingActions.count)))
        let left = Array((chrome.leadingActions + chrome.actions).dropFirst(count))
        lay(kept, behindMore: BarFit.groupsBehind(left: left, placed: chrome.overflow))
    }

    /// `chrome` with as many of the sidebar's part's groups on the bar as fit before the separator tracking the
    /// sidebar - the first in reading order - and the others behind the part's own More (`BarFit`).
    /// Design: docs/design/platforms/appkit/runtime.md#the-toolbar
    private func layFittingTheSidebar(_ chrome: AppKitWindowChrome) {
        guard chrome.sidebarGroups > 0 else {
            return lay(chrome, behindMore: [chrome.overflow], sidebarBehind: [chrome.sidebarOverflow])
        }
        let standing = BarFit.standing(groups: chrome.sidebarGroups) { trial in
            lay(chrome, keepingInTheSidebar: trial.groups)
            return sidebarFits
        }
        lay(chrome, keepingInTheSidebar: standing.groups)
    }

    /// `chrome` with the first `count` groups of the sidebar's part on the bar, the others behind its More.
    private func lay(_ chrome: AppKitWindowChrome, keepingInTheSidebar count: Int) {
        var kept = chrome
        kept.sidebarLeadingActions = Array(chrome.sidebarLeadingActions.prefix(count))
        kept.sidebarActions = Array(chrome.sidebarActions.prefix(max(0, count - chrome.sidebarLeadingActions.count)))
        let left = Array((chrome.sidebarLeadingActions + chrome.sidebarActions).dropFirst(count))
        lay(kept, behindMore: [chrome.overflow], sidebarBehind: BarFit.groupsBehind(left: left, placed: chrome.sidebarOverflow))
    }

    /// Whether every item of the sidebar's part stands in sight; true where the bar stands in no window.
    private var sidebarFits: Bool {
        guard let window, window.toolbar === toolbar,
              let separator = identifiers.firstIndex(of: .sidebarTrackingSeparator)
        else { return true }
        window.layoutIfNeeded()
        guard let visible = toolbar.visibleItems else { return true }
        let spaces: Set<NSToolbarItem.Identifier> = [.space, .flexibleSpace]
        let shown = Set(visible.map(\.itemIdentifier))
        return identifiers[..<separator].allSatisfy { spaces.contains($0) || shown.contains($0) }
    }

    /// Whether every item of the bar stands in sight in its window, none behind AppKit's own overflow; true where it
    /// stands in no window.
    private var fitsItsWindow: Bool {
        guard let window, window.toolbar === toolbar else { return true }
        window.layoutIfNeeded()
        guard let visible = toolbar.visibleItems else { return true }
        let spaces: Set<NSToolbarItem.Identifier> = [.space, .flexibleSpace]
        let shown = Set(visible.map(\.itemIdentifier))
        return toolbar.items.allSatisfy { spaces.contains($0.itemIdentifier) || shown.contains($0.itemIdentifier) }
    }

    /// Shows `chrome`, `behindMore` behind the bar's More and `sidebarBehind` behind the sidebar's part's.
    private func lay(
        _ chrome: AppKitWindowChrome, behindMore: [[AppKitToolbarAction]], sidebarBehind: [[AppKitToolbarAction]] = []
    ) {
        let behind = behindMore.filter { !$0.isEmpty }
        let sidebarBehind = sidebarBehind.filter { !$0.isEmpty }
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

        let place = { (groups: [[AppKitToolbarAction]]) in
            for (index, group) in groups.enumerated() {
                if index > 0 { nextIdentifiers.append(.space) }
                for action in group {
                    nextIdentifiers.append(action.identifier)
                    nextActions[action.identifier] = action
                }
            }
        }
        if chrome.sidebar != nil {
            if chrome.showsSidebarToggle { nextIdentifiers.append(.toggleSidebar) }
            place(chrome.sidebarLeadingActions)
            if !chrome.sidebarActions.isEmpty || !sidebarBehind.isEmpty {
                nextIdentifiers.append(.flexibleSpace)
                place(chrome.sidebarActions)
            }
            if !sidebarBehind.isEmpty {
                if !chrome.sidebarActions.isEmpty { nextIdentifiers.append(.space) }
                nextIdentifiers.append(Self.sidebarOverflow)
            }
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
        place(chrome.leadingActions)
        nextIdentifiers.append(.flexibleSpace)
        if let center {
            nextIdentifiers += [Self.center, .flexibleSpace]
            nextViews[Self.center] = center
        }
        place(chrome.actions)
        if !behind.isEmpty {
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
            && behind.map(\.count) == overflowGroups.map(\.count)
            && zip(behind.flatMap { $0 }, overflowActions).allSatisfy { $0.draws(like: $1) }
            && sidebarBehind.map(\.count) == sidebarOverflowGroups.map(\.count)
            && zip(sidebarBehind.flatMap { $0 }, sidebarOverflowActions).allSatisfy { $0.draws(like: $1) }
            && chrome.words == words

        identifiers = nextIdentifiers
        menus = menus.filter { nextActions[$0.key]?.menu != nil }
        sidebar = chrome.sidebar
        views = nextViews
        actions = nextActions
        overflowGroups = behind
        sidebarOverflowGroups = sidebarBehind
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
        let item: NSToolbarItem = if [Self.overflow, Self.sidebarOverflow].contains(itemIdentifier)
            || actions[itemIdentifier]?.menu != nil {
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

        if [Self.overflow, Self.sidebarOverflow].contains(identifier), let menuItem = item as? NSMenuToolbarItem {
            menuItem.image = NSImage(systemSymbolName: "ellipsis.circle", accessibilityDescription: words?.more)
            menuItem.label = words?.more ?? ""
            menuItem.showsIndicator = false
            menuItem.menu = identifier == Self.overflow
                ? overflowMenu(overflowGroups, numberedFrom: sidebarOverflowActions.count)
                : overflowMenu(sidebarOverflowGroups, numberedFrom: 0)
            return
        }

        guard let action = actions[identifier] else { return }
        if action.isLabel {
            item.label = action.title
            item.paletteLabel = action.title
            item.view = AppKitBarLabel(action.title, image: action.image)
            item.isBordered = false
            return
        }
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

    /// An overflow's menu of `groups`: each action an item - numbered on from `first` among every overflow's - an
    /// action opening a menu a submenu under its words.
    private func overflowMenu(_ groups: [[AppKitToolbarAction]], numberedFrom first: Int) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        // A line between two groups: before the first action of each group after the first.
        var firsts: Set<Int> = []
        var count = 0
        for group in groups.dropLast() {
            count += group.count
            firsts.insert(count)
        }
        for (index, action) in groups.flatMap({ $0 }).enumerated() {
            if firsts.contains(index) { menu.addItem(.separator()) }
            let item = NSMenuItem(
                title: action.title,
                action: #selector(performOverflow(_:)),
                keyEquivalent: "")
            item.target = self
            item.tag = first + index
            item.image = action.image
            item.isEnabled = action.isEnabled && !action.isLabel
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
        let every = sidebarOverflowActions + overflowActions
        guard every.indices.contains(sender.tag) else { return }
        every[sender.tag].perform()
    }

    var identifiersForTesting: [NSToolbarItem.Identifier] { identifiers }
    var sidebarForTesting: NSSplitViewController? { sidebar }

    var actionTitlesForTesting: [String] {
        identifiers.compactMap { $0 == Self.back || $0 == Self.close ? nil : actions[$0]?.title }
    }

    var overflowTitlesForTesting: [String] { overflowActions.map(\.title) }

    /// The actions behind the overflow, each by its identifier and whether it can be chosen.
    var overflowForTesting: [(identifier: NSToolbarItem.Identifier, isEnabled: Bool)] {
        overflowActions.map { ($0.identifier, $0.isEnabled && !$0.isLabel) }
    }

    /// The actions behind the sidebar's part's overflow, each by its identifier and whether it can be chosen.
    var sidebarOverflowForTesting: [(identifier: NSToolbarItem.Identifier, isEnabled: Bool)] {
        sidebarOverflowActions.map { ($0.identifier, $0.isEnabled && !$0.isLabel) }
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
              action.isEnabled, !action.isLabel
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
