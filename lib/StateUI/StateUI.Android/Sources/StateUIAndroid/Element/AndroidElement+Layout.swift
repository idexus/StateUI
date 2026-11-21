// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// Children placed: the layout item each child gives its parent.
extension AndroidElement {
    /// The view lays out, and its control writes, in the element's direction: View's LAYOUT_DIRECTION_LTR or _RTL.
    func directionChanged() {
        guard let view else { return }
        Java.call(view.reference, JavaAPI.setLayoutDirection, .int(element.layoutDirection == .rightToLeft ? 1 : 0))
        (view as? AndroidLayoutView)?.direction = element.layoutDirection
        (view as? AndroidTextualView)?.direction = element.layoutDirection
    }

    /// Hands a layout its children's items, in order, and a label the runs of its spans.
    func arrangeChildren() {
        if let items = view as? AndroidItemsView { return items.childrenChanged() }
        if let label = view as? AndroidTextView {
            return arrangeRuns(of: label)
        }
        let layout = view as? AndroidLayoutView
        layout?.direction = element.layoutDirection
        (view as? AndroidSplitView)?.framesDetail = element.arrangedChildren.dropFirst().first?.type == .page
        if keepsExits { layout?.keep(leavingViews()) }
        layout?.setItems(element.arrangedChildren.compactMap { $0.android.layoutItem })
    }

    /// The views of the children kept as they leave, each made deaf to touches and taken out of what assistive
    /// technology meets as it is found leaving.
    /// Design: docs/design/platforms/android/layout.md#a-view-kept-as-it-leaves
    private func leavingViews() -> [AndroidView] {
        element.presentedChildren.filter { $0.lifecycle == .exiting }.compactMap { child -> AndroidView? in
            guard let view = child.android.view else { return nil }
            view.setIgnoresInput(child.ignoresInput)
            view.setAccessibility(child.accessibilityWords) { _ in false }
            return view
        }
    }

    /// A stack, a grid and a ZStack keep a child that left: its view stands until the tree releases it.
    /// Design: docs/design/platforms/android/layout.md#a-view-kept-as-it-leaves
    var keepsExits: Bool {
        view is AndroidTravelingLayout
    }

    /// A label's spans as runs of its words, as the host layer reads them; without spans, its own words, once they
    /// are gone.
    private func arrangeRuns(of label: AndroidTextView) {
        guard let runs = element.textRuns else {
            if hasRuns {
                hasRuns = false
                let textCase = value(.textCase)?.enumeration.flatMap(TextCase.init(rawValue:)) ?? .none
                label.setText(textCase.applied(to: value(.text)?.string ?? ""))
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
    var layoutItem: AndroidLayoutItem? {
        guard let view else { return element.arrangedChildren.lazy.compactMap(\.android.layoutItem).first }

        var item = AndroidLayoutItem(view: view, values: element.layoutValues, isShown: isShown)
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
    var layoutParent: AndroidElement? {
        element.layoutParent?.native as? AndroidElement
    }
}
