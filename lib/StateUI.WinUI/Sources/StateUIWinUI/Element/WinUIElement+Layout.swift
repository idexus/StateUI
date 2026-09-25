// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// Children placed: the layout item each child gives its parent.
extension WinUIElement {
    /// Hands a layout its children's items, in order - a page's slots furnish it and stand in none of its room - and
    /// a label the runs of its spans.
    func arrangeChildren() {
        if let label = view as? WinUILabelView {
            return arrangeRuns(of: label)
        }
        let arranged = type == .page ? children.filter { !Self.slotTypes.contains($0.type) } : children
        let layout = view as? WinUILayoutView
        layout?.direction = element.layoutDirection
        layout?.setItems(arranged.compactMap(\.layoutItem))
    }

    /// A label's spans as runs of its words; without spans, its own words, once the runs are gone.
    private func arrangeRuns(of label: WinUILabelView) {
        guard let spans = children.first(where: { $0.type == .spans }) else {
            if hasRuns {
                hasRuns = false
                label.setText(WinUIRegistrations.cased(value(.text)?.string ?? "", textCase(of: self)))
            }
            return
        }

        hasRuns = true
        label.setRuns(spans.children.filter { $0.type == .span }.map { span in
            WinUILabelView.Run(
                text: WinUIRegistrations.cased(span.value(.text)?.string ?? "", textCase(of: span) ?? textCase(of: self)),
                color: span.value(.textColor),
                size: span.value(.fontSize)?.number,
                attributes: span.value(.fontAttributes)?.enumeration.map { FontAttributes(rawValue: $0) },
                background: span.value(.background),
                decorations: span.value(.textDecorations)?.enumeration.map { TextDecorations(rawValue: $0) })
        })
    }

    private func textCase(of element: WinUIElement) -> TextCase? {
        element.value(.textCase)?.enumeration.flatMap(TextCase.init(rawValue:))
    }

    /// What this element gives the layout it stands in: its view, or the first view of an element drawn by its parent.
    var layoutItem: WinUILayoutItem? {
        guard let view else { return children.lazy.compactMap(\.layoutItem).first }

        var item = WinUILayoutItem(view: view, values: element.layoutValues, isShown: isShown)
        item.mount = element.mount
        if fadesIn {
            item.fadeIn = { [weak self] motion in self?.fadeIn(under: motion) }
        }
        return item
    }

    /// Whether the view is shown: as the tree says, or while it fades out.
    var isShown: Bool {
        leaving || value(.isVisible)?.bool != false
    }

    /// The element whose layout places this one: the nearest above it with a view.
    var layoutParent: WinUIElement? {
        guard let parent else { return nil }
        return parent.view != nil ? parent : parent.layoutParent
    }
}
