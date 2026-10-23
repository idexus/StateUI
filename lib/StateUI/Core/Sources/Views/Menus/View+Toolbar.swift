// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

extension View {
    /// The actions on the bar of the page this stands in - or, declared on a
    /// split view, on the parts of its bar they name - declared where the
    /// state they follow lives.
    ///
    ///     VStack { … }
    ///         .toolbar {
    ///             ToolbarButton("Add").onClicked { items.append(Item()) }
    ///             ToolbarButton("Delete")
    ///                 .isEnabled(selected != nil)
    ///                 .onClicked { remove(selected) }
    ///         }
    ///
    /// They are built with the body declaring them, so an item follows the
    /// state it reads. A page's stand on its own bar while it is shown - a
    /// split view's sidebar and its detail each on their own, a page pushed
    /// onto a stack with none of the page under it - and go with it; a split
    /// view's stand over every page of their part. Each item or `ToolbarGroup`
    /// says where it stands with `.placement`. At an edge they stand by their
    /// order, then the split view's and a page's views further out at the
    /// edge, those further in nearer the title, then as declared. Written on
    /// a `NavigationStack` or a `TabView` it is left out, and said once.
    /// Declared on a disabled view, its items are disabled with it.
    ///
    /// - Parameter content: the items and groups, in reading order.
    public func toolbar(@ToolbarBuilder _ content: () -> ToolbarContent) -> Modified {
        let groups = content().groups
        // After the element's own children; the host finds them by type.
        // Design: docs/design/views/modifiers.md#slot-children
        return modified { $0.children.append(contentsOf: groups) }
    }
}
