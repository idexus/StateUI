// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

extension View {
    /// Shows what `content` describes in the platform's popover by this view while the state holds true, both
    /// ways: the user dismissing it - a tap beside it, Escape, the way back - writes false, and so does this view
    /// leaving.
    ///
    ///     @State private var filtering = false
    ///
    ///     Button("Filters")
    ///         .onClicked { filtering = true }
    ///         .popover(isPresented: $filtering) { FiltersPanel() }
    ///
    /// The content sizes the popover, and stands with the view whether it shows or not: its state lasts from one
    /// showing to the next. A view holds one popover: written again, it stands in.
    ///
    /// - Parameters:
    ///   - state: whether the popover shows, written false as it closes.
    ///   - content: what the popover shows.
    /// - Returns: this view, with its popover.
    public func popover<Content: View>(
        isPresented state: Binding<Bool>, @ViewBuilder content: @escaping () -> Content
    ) -> Modified {
        showing(PopoverElement(content: { [content().node] }, presented: state))
    }

    /// Shows in the platform's popover by this view what `content` makes of the value the state holds, while it
    /// holds one: the user dismissing it writes nil, and so does this view leaving. Another value shows what the
    /// content makes of it in its place.
    ///
    ///     @State private var explained: String?
    ///
    ///     Button("Why?")
    ///         .onClicked { explained = "Sync" }
    ///         .popover(item: $explained) { topic in Text(topic) }
    ///
    /// - Parameters:
    ///   - state: the value the popover shows, written nil as it closes.
    ///   - content: what the popover shows of a value.
    /// - Returns: this view, with its popover.
    public func popover<Item: Hashable, Content: View>(
        item state: Binding<Item?>, @ViewBuilder content: @escaping (Item) -> Content
    ) -> Modified {
        let item = state.wrappedValue
        let presented = Binding(get: { state.wrappedValue != nil }, set: { if !$0 { state.wrappedValue = nil } })
        return showing(PopoverElement(
            content: {
                item.map { item in
                    var shown = content(item).node
                    shown.identify(item)
                    return [shown]
                } ?? []
            },
            presented: presented))
    }

    /// This view with `popover`, in the place of one written before.
    /// Design: docs/design/views/modifiers.md#slot-children
    private func showing(_ popover: PopoverElement) -> Modified {
        modified {
            $0.children.removeAll { $0.type == PopoverContract.nodeType }
            $0.children.append(popover.node)
        }
    }
}

/// The popover a view declares, holding what it shows.
struct PopoverElement: ElementView {
    var node = Node(contract: PopoverContract.self)

    /// What `content` makes, shown while `state` holds true, the user's dismissal written back; leaving the tree
    /// writes false.
    init(content: @escaping () -> [Node], presented state: Binding<Bool>) {
        node.producer = content
        self = state.image == nil
            ? described(PopoverContract.isPresented.token, state, on: PopoverContract.isPresentedChanged.token)
            : plain(PopoverContract.isPresented.token, by: state, mode: .inOut)
        node.destroying.append { if state.wrappedValue { state.wrappedValue = false } }
    }
}
