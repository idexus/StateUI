// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

extension View {
    /// The actions on the bar of the page this stands in - or, declared on a
    /// stack or tabs, on the bar of every page they show, and on a split view,
    /// on the parts of its bar they name - declared where the state they
    /// follow lives.
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
    /// onto a stack with none of the page under it - and go with it; a stack's
    /// or tabs' stand over every page they show, a split view's over every
    /// page of their part. Each item or `ToolbarGroup` says where it stands
    /// with `.placement`. At an edge they stand by their order, then the
    /// arrangements' and a page's views further out at the edge, those further
    /// in nearer the title, then as declared. Declared on a disabled view, its
    /// items are disabled with it.
    ///
    /// - Parameter content: the items and groups, in reading order.
    public func toolbar(@ToolbarBuilder _ content: () -> ToolbarContent) -> Modified {
        let groups = content().groups
        // After the element's own children; the host finds them by type.
        // Design: docs/design/views/modifiers.md#slot-children
        return modified { $0.children.append(contentsOf: groups) }
    }
}
