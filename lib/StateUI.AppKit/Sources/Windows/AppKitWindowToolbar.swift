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

    /// Whether two actions draw the same toolbar item. What an action
    /// performs is taken again on every composition.
    func draws(like other: AppKitToolbarAction) -> Bool {
        identifier == other.identifier
            && title == other.title
            && image === other.image
            && isEnabled == other.isEnabled
    }
}

/// What a window's toolbar shows.
///
/// The window controller composes it from the visible arrangement and an
/// authored `TitleBar`, and the toolbar lays it out in one order: the
/// sidebar toggle and the separator that tracks the sidebar, the way back,
/// the page's title where a painted band hides the system's, the title bar's
/// leading content, the centre, the page's actions, native overflow, and the
/// title bar's trailing content.
@MainActor
struct AppKitWindowChrome {
    var sidebar: NSSplitViewController?
    var back: AppKitToolbarAction?
    var title: NSView?
    var leading: NSView?
    var center: NSView?
    var actions: [AppKitToolbarAction] = []
    var overflow: [AppKitToolbarAction] = []
    var trailing: NSView?
}

/// The one native toolbar of a StateUI window.
///
/// AppKit owns placement, overflow, the toolbar's material and window
/// dragging. StateUI owns what the items are: an action becomes a native
/// toolbar item, and an authored slot view is attached as it is, so its
/// identity and state stay StateUI's.
@MainActor
final class AppKitWindowToolbar: NSObject, NSToolbarDelegate {
    static let back = NSToolbarItem.Identifier("StateUI.back")
    static let title = NSToolbarItem.Identifier("StateUI.title")
    static let leading = NSToolbarItem.Identifier("StateUI.leading")
    static let center = NSToolbarItem.Identifier("StateUI.center")
    static let trailing = NSToolbarItem.Identifier("StateUI.trailing")
    static let overflow = NSToolbarItem.Identifier("StateUI.overflow")

    /// The system's own glyph for going back.
    static let backImage = NSImage(
        systemSymbolName: "chevron.backward",
        accessibilityDescription: "Back")

    let toolbar: NSToolbar

    private var identifiers: [NSToolbarItem.Identifier] = []
    private weak var sidebar: NSSplitViewController?
    private var views: [NSToolbarItem.Identifier: NSView] = [:]
    private var actions: [NSToolbarItem.Identifier: AppKitToolbarAction] = [:]
    private var overflowActions: [AppKitToolbarAction] = []

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
        var nextIdentifiers: [NSToolbarItem.Identifier] = []
        var nextViews: [NSToolbarItem.Identifier: NSView] = [:]
        var nextActions: [NSToolbarItem.Identifier: AppKitToolbarAction] = [:]

        if chrome.sidebar != nil {
            nextIdentifiers += [.toggleSidebar, .sidebarTrackingSeparator]
        }
        if let back = chrome.back {
            nextIdentifiers.append(Self.back)
            nextActions[Self.back] = back
        }
        if let title = chrome.title {
            nextIdentifiers.append(Self.title)
            nextViews[Self.title] = title
        }
        if let leading = chrome.leading {
            nextIdentifiers.append(Self.leading)
            nextViews[Self.leading] = leading
        }
        nextIdentifiers.append(.flexibleSpace)
        if let center = chrome.center {
            nextIdentifiers += [Self.center, .flexibleSpace]
            nextViews[Self.center] = center
        }
        for action in chrome.actions {
            nextIdentifiers.append(action.identifier)
            nextActions[action.identifier] = action
        }
        if !chrome.overflow.isEmpty { nextIdentifiers.append(Self.overflow) }
        if let trailing = chrome.trailing {
            nextIdentifiers.append(Self.trailing)
            nextViews[Self.trailing] = trailing
        }

        let sameItems = nextIdentifiers == identifiers
            && chrome.sidebar === sidebar
            && nextViews.count == views.count
            && nextViews.allSatisfy { views[$0.key] === $0.value }
        let drawsAlike = nextActions.allSatisfy { identifier, action in
            actions[identifier].map { $0.draws(like: action) } ?? false
        }
            && chrome.overflow.count == overflowActions.count
            && zip(chrome.overflow, overflowActions).allSatisfy { $0.draws(like: $1) }

        identifiers = nextIdentifiers
        sidebar = chrome.sidebar
        views = nextViews
        actions = nextActions
        overflowActions = chrome.overflow
        toolbar.centeredItemIdentifiers = chrome.center == nil ? [] : [Self.center]

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
        identifiers + [.flexibleSpace, .toggleSidebar, .sidebarTrackingSeparator]
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

        let item = itemIdentifier == Self.overflow
            ? NSMenuToolbarItem(itemIdentifier: itemIdentifier)
            : NSToolbarItem(itemIdentifier: itemIdentifier)
        configure(item)
        return item
    }

    private func configure(_ item: NSToolbarItem) {
        let identifier = item.itemIdentifier

        if let view = views[identifier] {
            item.view = view
            return
        }

        if identifier == Self.overflow, let menuItem = item as? NSMenuToolbarItem {
            menuItem.image = NSImage(
                systemSymbolName: "ellipsis.circle",
                accessibilityDescription: "More")
            menuItem.label = "More"
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
    }

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
            menu.addItem(item)
        }
        return menu
    }

    @objc private func performAction(_ sender: NSToolbarItem) {
        actions[sender.itemIdentifier]?.perform()
    }

    @objc private func performOverflow(_ sender: NSMenuItem) {
        guard overflowActions.indices.contains(sender.tag) else { return }
        overflowActions[sender.tag].perform()
    }

    var identifiersForTesting: [NSToolbarItem.Identifier] { identifiers }
    var sidebarForTesting: NSSplitViewController? { sidebar }

    var actionTitlesForTesting: [String] {
        identifiers.compactMap { $0 == Self.back ? nil : actions[$0]?.title }
    }

    var overflowTitlesForTesting: [String] { overflowActions.map(\.title) }

    func itemForTesting(_ identifier: NSToolbarItem.Identifier) -> NSToolbarItem? {
        toolbar.items.first { $0.itemIdentifier == identifier }
    }

    func itemForTesting(titled title: String) -> NSToolbarItem? {
        toolbar.items.first { $0.label == title && views[$0.itemIdentifier] == nil }
    }

    func performForTesting(_ identifier: NSToolbarItem.Identifier) {
        actions[identifier]?.perform()
    }
}

/// An authored title bar's own title: its mark, title and subtitle, standing
/// at the trailing edge of the window's title bar in the system's colours, or
/// in the bar's foreground over a painted band.
@MainActor
final class AppKitTitleBarTitleView: NSStackView {
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
        fatalError("AppKitTitleBarTitleView is created in code")
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
