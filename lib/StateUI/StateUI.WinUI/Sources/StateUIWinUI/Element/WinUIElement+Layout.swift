// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// Children placed: the layout item each child gives its parent.
extension WinUIElement {
    /// The view lays out, and its control writes, in the element's direction.
    func directionChanged() {
        view?.setDirection(element.layoutDirection)
    }

    func orderChildren() {
        (view as? WinUITravelingLayout)?.orderChildren()
    }

    /// Hands a layout its children's items, in order - a page's slots furnish it and stand in none of its room - and
    /// a label the runs of its spans.
    func arrangeChildren() {
        if let items = view as? WinUIItemsView { return items.childrenChanged() }
        if let label = view as? WinUITextView {
            return arrangeRuns(of: label)
        }
        let arranged = element.arrangedChildren.map(\.winUI)
        let layout = view as? WinUILayoutView
        layout?.direction = element.layoutDirection
        if keepsExits {
            layout?.keep(leavingViews(), presented: element.presentedMounts { $0.winUI.layoutItem?.mount }.mounts)
        }
        layout?.setItems(arranged.compactMap(\.layoutItem))
    }

    /// The views of the children kept as they leave, by their mounts, each made deaf to the pointer and taken out
    /// of what assistive technology meets as it is found leaving.
    /// Design: docs/design/platforms/winui/layout.md#a-view-kept-as-it-leaves
    private func leavingViews() -> [(mount: UInt64, view: WinUIView)] {
        element.presentedChildren.filter { $0.lifecycle == .exiting }.compactMap { child in
            guard let view = child.winUI.view else { return nil }
            view.setIgnoresInput(child.ignoresInput)
            view.setAccessibility(child.accessibilityWords)
            return (child.mount, view)
        }
    }

    /// A stack, a grid and a ZStack keep a child that left: its view stands until the tree releases it.
    /// Design: docs/design/platforms/winui/layout.md#a-view-kept-as-it-leaves
    var keepsExits: Bool {
        view is WinUITravelingLayout
    }

    /// A label's spans as runs of its words (`MountedElement.textRuns`); without spans, its own words, once the runs
    /// are gone.
    private func arrangeRuns(of label: WinUITextView) {
        guard let runs = element.textRuns else {
            if hasRuns {
                hasRuns = false
                label.setRuns(nil)
            }
            return
        }
        hasRuns = true
        label.setRuns(runs)
    }

    /// The element's own size and first baseline in the room offered, as its layout item measures them: what a
    /// layout's program asks of a child.
    func measured(width: Double?, height: Double?) -> HostChildMeasured {
        guard let item = layoutItem else { return HostChildMeasured(size: .zero, firstBaseline: nil) }
        return HostChildMeasured(size: item.size(offered: width), firstBaseline: item.firstBaseline(offered: width))
    }

    /// What this element gives the layout it stands in: its view, or the first view of an element drawn by its parent.
    var layoutItem: WinUILayoutItem? {
        guard let view else { return element.arrangedChildren.lazy.compactMap(\.winUI.layoutItem).first }

        var item = WinUILayoutItem(view: view, values: element.layoutValues, isShown: isShown)
        item.mount = element.mount
        if entersMoving {
            item.enter = { [weak self] entry in self?.enter(entry) }
        }
        return item
    }

    /// Whether the view is shown: as the tree says, or while it fades out.
    var isShown: Bool {
        element.standsShown
    }

    /// The element whose layout places this one: the nearest above it with a view (`MountedElement.layoutParent`).
    var layoutParent: WinUIElement? {
        element.layoutParent?.native as? WinUIElement
    }
}
