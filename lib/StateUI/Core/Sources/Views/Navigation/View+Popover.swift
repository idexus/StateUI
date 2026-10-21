// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

extension View {
    /// Shows what `content` describes in the platform's popover by this view while the state holds true, both
    /// ways: the user dismissing it - a tap beside it, Escape, the way back - writes false.
    ///
    ///     @State private var filtering = false
    ///
    ///     Button("Filters")
    ///         .onClicked { filtering = true }
    ///         .popover(isShown: $filtering) { FiltersPanel() }
    ///
    /// A phone shows a popover as a sheet, as its platform does. The content sizes the popover; it is built while
    /// the popover shows.
    ///
    /// - Parameters:
    ///   - state: whether the popover shows, written false as the user dismisses it.
    ///   - content: what the popover shows.
    /// - Returns: this view, with its popover.
    public func popover<Content: View>(
        isShown state: Binding<Bool>, @ViewBuilder content: @escaping () -> Content
    ) -> Modified {
        let popover = PopoverElement(content: content).isShown(state)
        return modified {
            // After the view's own children, one; written again it stands in.
            // Design: docs/design/views/modifiers.md#slot-children
            $0.children.removeAll { $0.type == PopoverContract.nodeType }
            $0.children.append(popover.node)
        }
    }
}

/// The popover a view declares, holding what it shows.
struct PopoverElement: ElementView {
    var node = Node(contract: PopoverContract.self)

    init<Content: View>(content: @escaping () -> Content) {
        node.producer = { content().nodes }
    }

    /// Shown as the state says, the user's dismissal written back.
    func isShown(_ state: Binding<Bool>) -> Self {
        state.image == nil
            ? described(PopoverContract.isShown.token, state, on: PopoverContract.isShownChanged.token)
            : plain(PopoverContract.isShown.token, by: state, mode: .inOut)
    }
}
