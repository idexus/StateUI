// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The bar at a page's foot (`.toolbar(.bottom)`): a strip of AppKit's accessory bar controls, its leading groups at
/// its start and the rest at its end, a More button opening the menu of those placed in the overflow - each group's
/// items close together, the groups apart.
/// Design: docs/design/platforms/appkit/runtime.md#the-bar-at-the-foot
@MainActor
final class AppKitBottomToolbar: NSView {
    /// How tall the strip stands.
    static let height = 28.0

    private let leading = NSStackView()
    private let trailing = NSStackView()

    /// The actions as the strip last drew them: the leading groups, the trailing, the overflow.
    private var shown: (leading: [[AppKitToolbarAction]], trailing: [[AppKitToolbarAction]], overflow: [AppKitToolbarAction])
        = ([], [], [])

    /// What each control performs, by its identifier; taken again at every showing.
    private var actions: [NSUserInterfaceItemIdentifier: AppKitToolbarAction] = [:]

    /// The menu the More button opens.
    private let overflowMenu = NSMenu()

    override var isFlipped: Bool { true }

    init() {
        super.init(frame: .zero)
        for stack in [leading, trailing] {
            stack.orientation = .horizontal
            stack.spacing = 12
            addSubview(stack)
        }
        overflowMenu.autoenablesItems = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    /// Whether the strip holds anything to show.
    var holdsItems: Bool {
        !(shown.leading.isEmpty && shown.trailing.isEmpty && shown.overflow.isEmpty)
    }

    /// Shows `actions`, its controls made again only where they draw otherwise.
    func show(_ actions: ChromeActions) {
        let make = { (groups: [[MountedElement]]) in groups.map { $0.map(AppKitWindowController.action) } }
        let next = (leading: make(actions.start), trailing: make(actions.end),
                    overflow: actions.overflow.map(AppKitWindowController.action))
        self.actions = Dictionary(
            (next.leading + next.trailing + [next.overflow]).joined().map { (Self.identifier($0), $0) },
            uniquingKeysWith: { first, _ in first })
        let same = { (one: [[AppKitToolbarAction]], other: [[AppKitToolbarAction]]) in
            one.count == other.count && zip(one, other).allSatisfy { pair in
                pair.0.count == pair.1.count && zip(pair.0, pair.1).allSatisfy { $0.draws(like: $1) }
            }
        }
        guard !same(next.leading, shown.leading) || !same(next.trailing, shown.trailing)
            || !same([next.overflow], [shown.overflow])
        else { return }
        shown = next
        leading.setViews(next.leading.map(group), in: .leading)
        let more = next.overflow.isEmpty ? [] : [moreButton(words: CoreLink().chromeWords)]
        trailing.setViews(next.trailing.map(group) + more, in: .leading)
        fillOverflow(next.overflow)
        needsLayout = true
    }

    /// One group's controls, close together.
    private func group(_ actions: [AppKitToolbarAction]) -> NSView {
        let stack = NSStackView(views: actions.map(control))
        stack.orientation = .horizontal
        stack.spacing = 2
        return stack
    }

    /// The control standing for `action`: words for a label, a button for an action or a setting, one opening its
    /// menu where it holds one.
    private func control(_ action: AppKitToolbarAction) -> NSView {
        let identifier = Self.identifier(action)
        if action.isLabel {
            let label = AppKitBarLabel(action.title, image: action.image)
            label.identifier = identifier
            return label
        }
        if let menu = action.menu, menu.opening != .click {
            let menuShown = NSMenu()
            menuShown.autoenablesItems = false
            AppKitMenus.items(menu.entries).forEach { item in
                item.menu?.removeItem(item)
                menuShown.addItem(item)
            }
            let button = NSComboButton(
                title: action.image == nil ? action.title : "", menu: menuShown, target: self,
                action: #selector(choose(_:)))
            button.image = action.image
            button.style = .split
            button.controlSize = .small
            button.identifier = identifier
            button.isEnabled = action.isEnabled
            button.toolTip = action.title
            return button
        }
        let button = NSButton(title: action.image == nil ? action.title : "", target: self, action: #selector(choose(_:)))
        button.image = action.image
        button.imagePosition = action.image == nil ? .noImage : .imageOnly
        button.bezelStyle = .accessoryBarAction
        button.controlSize = .small
        button.identifier = identifier
        button.isEnabled = action.isEnabled
        button.toolTip = action.title
        button.setAccessibilityLabel(action.title)
        if let isOn = action.isOn {
            button.setButtonType(.pushOnPushOff)
            button.state = isOn ? .on : .off
        }
        return button
    }

    /// The button opening the overflow's menu, named by `words`.
    private func moreButton(words: ChromeWords) -> NSView {
        let button = NSButton(title: "", target: self, action: #selector(openOverflow(_:)))
        button.image = NSImage(systemSymbolName: "ellipsis.circle", accessibilityDescription: words.more)
        button.imagePosition = .imageOnly
        button.bezelStyle = .accessoryBarAction
        button.controlSize = .small
        button.toolTip = words.more
        button.identifier = Self.more
        return button
    }

    /// The overflow's menu: each action an item, a line between two groups' sections.
    private func fillOverflow(_ overflow: [AppKitToolbarAction]) {
        overflowMenu.removeAllItems()
        for action in overflow {
            let item = NSMenuItem(title: action.title, action: #selector(choose(_:)), keyEquivalent: "")
            item.target = self
            item.identifier = Self.identifier(action)
            item.image = action.image
            item.isEnabled = action.isEnabled && !action.isLabel
            item.state = action.isOn == true ? .on : .off
            overflowMenu.addItem(item)
        }
    }

    @objc private func choose(_ sender: NSUserInterfaceItemIdentification) {
        sender.identifier.flatMap { actions[$0] }?.perform()
    }

    @objc private func openOverflow(_ sender: NSButton) {
        overflowMenu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.maxY + 4), in: sender)
    }

    override func layout() {
        super.layout()
        let inset = 8.0
        let size = { (stack: NSStackView) in stack.fittingSize }
        let start = size(leading), end = size(trailing)
        leading.frame = NSRect(x: inset, y: (bounds.height - start.height) / 2, width: start.width, height: start.height)
        trailing.frame = NSRect(
            x: bounds.width - inset - end.width, y: (bounds.height - end.height) / 2, width: end.width, height: end.height)
    }

    /// The identifier of `action`'s control, its toolbar item's.
    private static func identifier(_ action: AppKitToolbarAction) -> NSUserInterfaceItemIdentifier {
        NSUserInterfaceItemIdentifier(action.identifier.rawValue)
    }

    /// The identifier of the More button.
    static let more = NSUserInterfaceItemIdentifier("StateUI.overflow")

    // MARK: - What a test reads

    /// What the strip shows, each control by its identifier and whether it can be chosen: the leading groups, the
    /// trailing groups, and the overflow's items.
    var shownForTesting: (leading: [[(String, Bool)]], trailing: [[(String, Bool)]], overflow: [(String, Bool)]) {
        let said = { (stack: NSStackView) in
            stack.arrangedSubviews.compactMap { $0 as? NSStackView }.map { group in
                group.arrangedSubviews.map { control in
                    (control.identifier?.rawValue ?? "", (control as? NSControl)?.isEnabled ?? true)
                }
            }
        }
        let items = overflowMenu.items.map { ($0.identifier?.rawValue ?? "", $0.isEnabled) }
        return (said(leading), said(trailing), items)
    }

    /// The control or overflow item standing for `identifier`; nil for none.
    func controlForTesting(_ identifier: String) -> NSUserInterfaceItemIdentification? {
        let controls = (leading.arrangedSubviews + trailing.arrangedSubviews).compactMap { $0 as? NSStackView }
            .flatMap(\.arrangedSubviews)
        return controls.first { $0.identifier?.rawValue == identifier }
            ?? overflowMenu.items.first { $0.identifier?.rawValue == identifier }
    }

    /// Chooses the overflow's item `item`, as the user does.
    func chooseForTesting(_ item: NSMenuItem) {
        guard item.isEnabled else { return }
        choose(item)
    }
}

#endif
