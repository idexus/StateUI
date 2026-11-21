// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What a layout holds: its children's views, each as the item the host layer's arithmetic places; and a label, the
/// runs of its spans.
extension UIKitElement {
    /// The view lays out, and its control writes, in the element's direction.
    func directionChanged() {
        view?.semanticContentAttribute = element.layoutDirection == .rightToLeft ? .forceRightToLeft : .forceLeftToRight
        (view as? any UIKitLabel)?.directionTurned()
    }

    func arrangeChildren() {
        if let items = view as? UIKitItemsView { return items.childrenChanged() }
        if let label = view as? any UIKitLabel { return label.setRuns(element.textRuns) }
        guard let layout = view as? UIKitLayoutView else { return }
        layout.direction = element.layoutDirection
        layout.laidOut = { [weak host] in host?.runtime.frames.laidOut() }
        if keepsExits { layout.keep(leavingViews()) }
        layout.setItems(element.arrangedChildren.compactMap { $0.uiKit.layoutItem })
    }

    /// The views of the children kept as they leave, each made deaf to input and taken out of what assistive
    /// technology meets as it is found leaving.
    /// Design: docs/design/platforms/uikit/layout.md#a-view-kept-as-it-leaves
    private func leavingViews() -> [UIView] {
        element.presentedChildren.filter { $0.lifecycle == .exiting }.compactMap { child -> UIView? in
            guard let view = child.uiKit.view else { return nil }
            view.isUserInteractionEnabled = !child.ignoresInput
            child.uiKit.applyAccessibility()
            return view
        }
    }

    /// A stack, a grid and a ZStack keep a child that left: its view stands until the tree releases it.
    /// Design: docs/design/platforms/uikit/layout.md#a-view-kept-as-it-leaves
    var keepsExits: Bool {
        view is UIKitStackView || view is UIKitGridView || view is UIKitZStackView
    }

    /// The element's own size and first baseline in the room offered, as its layout item measures them: what a
    /// layout's program asks of a child.
    func measured(width: Double?, height: Double?) -> HostChildMeasured {
        guard let item = layoutItem else { return HostChildMeasured(size: .zero, firstBaseline: nil) }
        return HostChildMeasured(size: item.size(offered: width), firstBaseline: item.firstBaseline(offered: width))
    }

    /// What this element gives the layout it stands in: its view, or the first view of an element drawn by its
    /// parent.
    var layoutItem: UIKitLayoutItem? {
        guard let view else { return element.arrangedChildren.lazy.compactMap(\.uiKit.layoutItem).first }

        var item = UIKitLayoutItem(view: view, values: element.layoutValues, isShown: element.standsShown)
        item.mount = element.mount
        item.placed = self
        item.drawing = drawing
        if entersMoving {
            item.enter = { [weak self] entry in self?.enter(entry) }
        }
        return item
    }
}
#endif
