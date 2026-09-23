// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI

/// Children placed: the layout item each child gives its parent.
extension AppKitElement {
    func arrangeChildren() {
        guard let view else { return }
        let items = children.compactMap(\.layoutItem)

        if let label = view as? AppKitLabelView {
            label.apply(
                attributedText: attributedLabelText(),
                padding: insets(.padding),
                horizontalAlignment: textAlignment(enumeration(.horizontalTextAlignment)),
                verticalAlignment: AppKitVerticalTextAlignment(
                    rawValue: enumeration(.verticalTextAlignment) ?? 0) ?? .start,
                lineBreakMode: lineBreakMode(enumeration(.lineBreak)),
                maximumNumberOfLines: effectiveMaximumLines())
            return
        }

        if let stack = view as? AppKitStackView {
            stack.setItems(items)
            return
        }

        if let split = view as? AppKitSplitView {
            split.setItems(items)
            return
        }

        if let navigation = view as? AppKitNavigationView {
            navigation.setItems(items)
            return
        }

        if let tabs = view as? AppKitTabbedView {
            let tabItems = children.compactMap { child -> AppKitTabItem? in
                guard let layout = child.layoutItem else { return nil }
                return AppKitTabItem(
                    layout: layout,
                    title: child.string(.title),
                    image: child.string(.icon).flatMap { image(named: $0) })
            }
            tabs.onSelection = { [weak self] previous, selected in
                self?.selectTab(from: previous, to: selected)
            }
            pendingTabFallback = tabs.setItems(
                tabItems,
                requestedIndex: whole(.currentPage))
            return
        }

        if let page = view as? AppKitSingleChildView {
            page.setItem(items.first)
            return
        }

        if let grid = view as? AppKitGridView {
            grid.setItems(items)
            return
        }

        if let absolute = view as? AppKitAbsoluteLayoutView {
            absolute.setItems(
                items,
                retaining: recycledChildren.compactMap(\.layoutItem),
                preservesSubviewOrder: recycles)
            return
        }

        if let scroll = view as? AppKitScrollView {
            scroll.setItems(items)
        }
    }

    var layoutItem: AppKitLayoutItem? {
        guard let view = presentableViews.first else { return nil }
        var item = AppKitLayoutItem(view: view)
        item.margin = insets(.margin)
        item.horizontal = enumeration(.horizontalAlignment) ?? 3
        item.vertical = enumeration(.verticalAlignment) ?? 3
        item.width = requested(.width)
        item.height = requested(.height)
        item.minimumWidth = requested(.minimumWidth)
        item.minimumHeight = requested(.minimumHeight)
        item.maximumWidth = requested(.maximumWidth)
        item.maximumHeight = requested(.maximumHeight)
        item.row = whole(.gridRow) ?? 0
        item.column = whole(.gridColumn) ?? 0
        item.rowSpan = max(whole(.gridRowSpan) ?? 1, 1)
        item.columnSpan = max(whole(.gridColumnSpan) ?? 1, 1)
        item.absoluteBounds = value(.absoluteLayoutBounds)?.numbers
        item.absoluteProportions = enumeration(.absoluteLayoutProportions) ?? 0
        item.drawing = presentableDrawing
        item.mount = mount
        item.placed = presentableNode
        if fadesIn {
            item.fadeIn = { [weak self] motion in self?.fadeIn(under: motion) }
        }
        return item
    }

    /// The element whose view `presentableViews` puts first.
    var presentableNode: AppKitElement? {
        if view != nil { return self }
        return children.lazy.compactMap(\.presentableNode).first
    }

    /// The drawing of the view `presentableViews` puts first.
    var presentableDrawing: AppKitViewDrawing? {
        if view != nil { return drawing }
        return children.lazy.compactMap(\.presentableDrawing).first
    }

    var presentableViews: [NSView] {
        if let view { return [view] }
        return children.flatMap(\.presentableViews)
    }

    /// The first native view authored into one structural child slot.
    func firstView(in slot: NodeType) -> NSView? {
        self.slot(slot)?.presentableViews.first
    }

    func slot(_ type: NodeType) -> AppKitElement? {
        children.first { $0.type == type }
    }
}
#endif
