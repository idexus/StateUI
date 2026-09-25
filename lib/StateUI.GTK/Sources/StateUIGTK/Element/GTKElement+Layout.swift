// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// Children placed: the layout item each child gives its parent.
extension GTKElement {
    /// Hands a layout its children's items, in order - a page's slots furnish its header bar and stand in none of
    /// its room - and a label the runs of its spans.
    func arrangeChildren() {
        if let label = view as? GTKLabelView {
            return arrangeRuns(of: label)
        }
        let arranged = type == .page ? children.filter { !Self.slotTypes.contains($0.type) } : children
        (view as? GTKNavigationView)?.titles = arranged.map { $0.visiblePage?.value(.title)?.string ?? "" }
        (view as? GTKSplitView)?.framedPanes = arranged.map { Self.framedTypes.contains($0.type) }
        let layout = view as? GTKLayoutView
        layout?.direction = element.layoutDirection
        layout?.setItems(arranged.compactMap(\.layoutItem))
    }

    /// A label's spans as runs of its words; without spans, its own words, once the runs are gone.
    private func arrangeRuns(of label: GTKLabelView) {
        guard let spans = children.first(where: { $0.type == .spans }) else {
            if hasRuns {
                hasRuns = false
                label.setRuns(nil)
            }
            return
        }

        hasRuns = true
        label.setRuns(spans.children.filter { $0.type == .span }.map { span in
            var look = GTKTextLook()
            look.size = span.value(.fontSize)?.number
            look.attributes = span.value(.fontAttributes)?.enumeration.map { FontAttributes(rawValue: $0) } ?? .none
            look.color = span.value(.textColor).flatMap(GTKBrush.rgba)
            look.background = GTKBrush(span.value(.background)).firstColor
            look.decorations = span.value(.textDecorations)?.enumeration.map { TextDecorations(rawValue: $0) } ?? .none
            let textCase = (span.value(.textCase) ?? value(.textCase))?.enumeration.flatMap(TextCase.init(rawValue:))
            return GTKTextView.Run(
                text: GTKRegistrations.cased(span.value(.text)?.string ?? "", textCase), look: look)
        })
    }

    /// What this element gives the layout it stands in: its view, or the first view of an element drawn by its parent.
    var layoutItem: GTKLayoutItem? {
        guard let view else { return children.lazy.compactMap(\.layoutItem).first }

        var item = GTKLayoutItem(view: view, values: element.layoutValues, isShown: isShown)
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
    var layoutParent: GTKElement? {
        guard let parent else { return nil }
        return parent.view != nil ? parent : parent.layoutParent
    }
}
