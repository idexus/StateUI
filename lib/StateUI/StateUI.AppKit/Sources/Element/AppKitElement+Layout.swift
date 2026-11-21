// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// Children placed: the layout item each child gives its parent.
extension AppKitElement {
    /// The view lays out, and its control writes, in the element's direction; a text's and a button's padding stand
    /// by it.
    func directionChanged() {
        view?.userInterfaceLayoutDirection = element.layoutDirection == .rightToLeft ? .rightToLeft : .leftToRight
        if let button = view as? NSButton, value(.padding) != nil {
            (button.cell as? AppKitButtonCell)?.padding = nativeInsets(.padding)
        }
        if view is AppKitTextView { arrangeChildren() }
    }

    func invalidateMeasurements() {
        view?.invalidateMeasurements()
    }

    func orderChildren() {
        (view as? AppKitTravelingLayout)?.orderChildren()
    }

    func arrangeChildren() {
        guard let view else { return }
        if let items = view as? AppKitItemsView { return items.childrenChanged() }
        let items = element.arrangedChildren.map(\.appKit).compactMap(\.layoutItem)
        let presented = presentedViews()
        (view as? AppKitDirectedLayout)?.direction = element.layoutDirection

        if let label = view as? AppKitTextView {
            label.apply(
                attributedText: attributedLabelText(),
                padding: nativeInsets(.padding),
                horizontalAlignment: NSTextAlignment(
                    enumeration(.horizontalTextAlignment).flatMap(TextAlignment.init(rawValue:)),
                    in: label.userInterfaceLayoutDirection),
                verticalAlignment: AppKitVerticalTextAlignment(
                    rawValue: enumeration(.verticalTextAlignment) ?? 0) ?? .start,
                breaking: lineBreak,
                maximumNumberOfLines: maximumLines())
            label.isSelectable = value(.isSelectable)?.bool == true
            return
        }

        if let stack = view as? AppKitStackView {
            stack.setItems(items, presenting: presented)
            return
        }

        if let split = view as? AppKitSplitView {
            split.setItems(items)
            split.setColumns(sidebar: element.arrangedChildren.first, detail: element.arrangedChildren.dropFirst().first)
            return
        }

        if let navigation = view as? AppKitNavigationView {
            navigation.setItems(items)
            return
        }

        if let tabs = view as? AppKitTabView {
            arrangeTabs(tabs)
            return
        }

        if let page = view as? AppKitSingleChildView {
            page.setItem(items.first)
            return
        }

        if let grid = view as? AppKitGridView {
            grid.setItems(items, presenting: presented)
            return
        }

        if let layers = view as? AppKitZStackView {
            layers.setItems(items, presenting: presented)
            return
        }

        if let scroll = view as? AppKitScrollView {
            scroll.setItems(items)
        }
    }

    /// The views that stand in this element's: its arranged children's, and those of children kept as they leave,
    /// each made deaf to input and out of what assistive technology meets as it is found leaving - the layout told
    /// the mounts of those.
    /// Design: docs/design/platforms/appkit/views.md#a-view-kept-as-it-leaves
    private func presentedViews() -> [NSView] {
        var kept: [ObjectIdentifier: UInt64] = [:]
        let views = element.presentedChildren.flatMap { child -> [NSView] in
            let views = child.appKit.presentableViews
            if child.lifecycle == .exiting {
                child.appKit.applyVisibility()
                for view in views {
                    child.appKit.applyAccessibility(to: view)
                    kept[ObjectIdentifier(view)] = child.mount
                }
            }
            return views
        }
        (view as? AppKitTravelingLayout)?.keptMounts = kept
        return views
    }

    /// The element's own size and first baseline in the room offered, as its layout item measures them: what a
    /// layout's program asks of a child.
    func measured(width: Double?, height: Double?) -> HostChildMeasured {
        guard let item = layoutItem else { return HostChildMeasured(size: .zero, firstBaseline: nil) }
        return HostChildMeasured(size: item.size(offered: width), firstBaseline: item.firstBaseline(offered: width))
    }

    var layoutItem: AppKitLayoutItem? {
        guard let view = presentableViews.first else { return nil }
        var item = AppKitLayoutItem(view: view)
        item.values = element.layoutValues
        item.drawing = presentableDrawing
        item.mount = mount
        item.placed = presentableNode
        if entersMoving {
            item.enter = { [weak self] entry in self?.enter(entry) }
        }
        return item
    }

    /// The element whose view `presentableViews` puts first.
    var presentableNode: AppKitElement? {
        if view != nil { return self }
        return element.arrangedChildren.lazy.compactMap(\.appKit.presentableNode).first
    }

    /// The drawing of the view `presentableViews` puts first.
    var presentableDrawing: AppKitViewDrawing? {
        if view != nil { return drawing }
        return element.arrangedChildren.lazy.compactMap(\.appKit.presentableDrawing).first
    }

    var presentableViews: [NSView] {
        if let view { return [view] }
        return element.arrangedChildren.flatMap(\.appKit.presentableViews)
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
