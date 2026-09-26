// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// Children placed: the layout item each child gives its parent.
extension AndroidElement {
    /// Hands a layout its children's items, in order, and a label the runs of its spans.
    func arrangeChildren() {
        if let label = view as? AndroidLabelView {
            return arrangeRuns(of: label)
        }
        let layout = view as? AndroidLayoutView
        layout?.direction = element.layoutDirection
        layout?.setItems(element.arrangedChildren.compactMap { $0.android.layoutItem })
    }

    /// A label's spans as runs of its words, as the host layer reads them; without spans, its own words, once they
    /// are gone.
    private func arrangeRuns(of label: AndroidLabelView) {
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

    /// What this element gives the layout it stands in: its view, or the first view of an element drawn by its parent.
    var layoutItem: AndroidLayoutItem? {
        guard let view else { return children.lazy.compactMap(\.layoutItem).first }

        var item = AndroidLayoutItem(view: view, values: element.layoutValues, isShown: isShown)
        item.mount = element.mount
        if fadesIn {
            item.fadeIn = { [weak self] motion in self?.fadeIn(under: motion) }
        }
        return item
    }

    /// Whether the view is shown: as the tree says, or while it fades out.
    var isShown: Bool {
        element.standsShown
    }

    /// The element whose layout places this one: the nearest above it with a view.
    var layoutParent: AndroidElement? {
        guard let parent else { return nil }
        return parent.view != nil ? parent : parent.layoutParent
    }
}
