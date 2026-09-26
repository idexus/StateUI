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
        let arranged = type == .page ? children.filter { !Self.slotTypes.contains($0.type) } : children
        let layout = view as? AndroidLayoutView
        layout?.direction = element.layoutDirection
        layout?.setItems(arranged.compactMap(\.layoutItem))
    }

    /// A label's spans as runs of its words; without spans, its own words, once they are gone.
    private func arrangeRuns(of label: AndroidLabelView) {
        guard let spans = children.first(where: { $0.type == .spans }) else {
            if hasRuns {
                hasRuns = false
                label.setText(AndroidRegistrations.cased(value(.text)?.string ?? "", textCase(of: self)))
            }
            return
        }

        hasRuns = true
        label.setRuns(spans.children.filter { $0.type == .span }.map { span in
            AndroidLabelView.Run(
                text: AndroidRegistrations.cased(span.value(.text)?.string ?? "", textCase(of: span) ?? textCase(of: self)),
                color: span.value(.textColor),
                size: span.value(.fontSize)?.number,
                attributes: span.value(.fontAttributes)?.enumeration.map { FontAttributes(rawValue: $0) },
                background: span.value(.background),
                decorations: span.value(.textDecorations)?.enumeration.map { TextDecorations(rawValue: $0) })
        })
    }

    private func textCase(of element: AndroidElement) -> TextCase? {
        element.value(.textCase)?.enumeration.flatMap(TextCase.init(rawValue:))
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
