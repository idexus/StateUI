// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI

/// Owns the native toolbar used for one authored StateUI title area.
///
/// The toolbar owns placement and overflow. StateUI continues to own the
/// identity and contents of each slot view, which are attached directly to
/// custom toolbar items instead of being copied into a second native tree.
@MainActor
final class AppKitTitleBarController: NSObject, NSToolbarDelegate {
    let toolbar: NSToolbar

    private let leadingIdentifier = NSToolbarItem.Identifier("StateUI.TitleBar.leading")
    private let titleIdentifier = NSToolbarItem.Identifier("StateUI.TitleBar.title")
    private let centerIdentifier = NSToolbarItem.Identifier("StateUI.TitleBar.center")
    private let trailingIdentifier = NSToolbarItem.Identifier("StateUI.TitleBar.trailing")
    private let titleView = AppKitTitleBarTitleView()
    private var currentIdentifiers: [NSToolbarItem.Identifier] = []
    private var views: [NSToolbarItem.Identifier: NSView] = [:]

    init(windowIdentifier: String) {
        toolbar = NSToolbar(identifier: NSToolbar.Identifier(
            "StateUI.TitleBar.\(windowIdentifier)"))
        super.init()

        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = false
    }

    /// Applies the authored values and exact slot arrangement.
    func synchronize(_ node: MountedNode) {
        let title = node.string(.title)
        let subtitle = node.string(.subtitle)
        let icon = node.image(.icon)
        let hasTitle = title != nil || subtitle != nil || icon != nil

        titleView.apply(
            title: title ?? "",
            subtitle: subtitle ?? "",
            image: icon,
            foregroundColor: node.color(.foregroundColor))

        let leading = node.firstView(in: .leadingContent)
        let center = node.firstView(in: .content)
        let trailing = node.firstView(in: .trailingContent)
        var nextViews: [NSToolbarItem.Identifier: NSView] = [:]

        if let leading { nextViews[leadingIdentifier] = leading }
        if hasTitle { nextViews[titleIdentifier] = titleView }
        if let center { nextViews[centerIdentifier] = center }
        if let trailing { nextViews[trailingIdentifier] = trailing }

        let centered = center != nil
            ? centerIdentifier
            : (hasTitle ? titleIdentifier : nil)
        let nextIdentifiers = arrangement(
            leading: leading != nil,
            title: hasTitle,
            center: center != nil,
            trailing: trailing != nil)
        let keepsViews = nextIdentifiers == currentIdentifiers
            && nextViews.allSatisfy { identifier, view in
                views[identifier] === view
            }
            && views.count == nextViews.count

        views = nextViews
        toolbar.centeredItemIdentifiers = centered.map { [$0] } ?? []

        guard !keepsViews else { return }
        currentIdentifiers = nextIdentifiers

        while !toolbar.items.isEmpty {
            toolbar.removeItem(at: toolbar.items.count - 1)
        }
        for (index, identifier) in nextIdentifiers.enumerated() {
            toolbar.insertItem(withItemIdentifier: identifier, at: index)
        }
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        currentIdentifiers
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [
            leadingIdentifier,
            titleIdentifier,
            centerIdentifier,
            trailingIdentifier,
            .flexibleSpace,
        ]
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        guard let view = views[itemIdentifier] else { return nil }

        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.label = label(for: itemIdentifier)
        item.paletteLabel = item.label
        item.view = view
        return item
    }

    private func arrangement(
        leading: Bool,
        title: Bool,
        center: Bool,
        trailing: Bool
    ) -> [NSToolbarItem.Identifier] {
        var identifiers: [NSToolbarItem.Identifier] = []

        if leading { identifiers.append(leadingIdentifier) }
        if title && center { identifiers.append(titleIdentifier) }

        if title || center {
            identifiers.append(.flexibleSpace)
            identifiers.append(center ? centerIdentifier : titleIdentifier)
            identifiers.append(.flexibleSpace)
        } else if leading || trailing {
            identifiers.append(.flexibleSpace)
        }

        if trailing { identifiers.append(trailingIdentifier) }
        return identifiers
    }

    private func label(for identifier: NSToolbarItem.Identifier) -> String {
        switch identifier {
        case leadingIdentifier: "Leading content"
        case titleIdentifier: "Window title"
        case centerIdentifier: "Title content"
        case trailingIdentifier: "Trailing content"
        default: ""
        }
    }
}

/// The native text-and-image cluster used when a `TitleBar` supplies its own
/// title values rather than filling only the three authored slots.
@MainActor
private final class AppKitTitleBarTitleView: NSStackView {
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let textStack = NSStackView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        orientation = .horizontal
        alignment = .centerY
        spacing = 6

        iconView.imageScaling = .scaleProportionallyDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),
        ])

        titleLabel.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
        titleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
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

    func apply(
        title: String,
        subtitle: String,
        image: NSImage?,
        foregroundColor: NSColor?
    ) {
        titleLabel.stringValue = title
        titleLabel.isHidden = title.isEmpty
        subtitleLabel.stringValue = subtitle
        subtitleLabel.isHidden = subtitle.isEmpty
        iconView.image = image
        iconView.isHidden = image == nil

        titleLabel.textColor = foregroundColor ?? .labelColor
        subtitleLabel.textColor = foregroundColor ?? .secondaryLabelColor
    }
}

#endif
