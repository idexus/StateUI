// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

extension View {
    /// A group of actions on the bar of the page this stands in, declared where
    /// the state they follow lives.
    ///
    ///     VStack { … }
    ///         .toolbar {
    ///             ToolbarItem("Add").onClicked { items.append(Item()) }
    ///             ToolbarItem("Delete")
    ///                 .isEnabled(selected != nil)
    ///                 .onClicked { remove(selected) }
    ///         }
    ///
    /// The group is built with the body declaring it, so an item follows the
    /// state it reads. It stands on the bar while the page it belongs to is
    /// shown: declared on a view, the page holding the view; declared on a
    /// `NavigationStack`, a `TabView`, a `SplitView` or a window's page,
    /// every page shown in it. Groups declared further in join those declared
    /// around them, nearer the title, so an action of the window keeps its
    /// place from page to page; when a page goes, its groups go with it.
    ///
    /// One declaration is one group, drawn with one shared background where the
    /// platform groups its bar's actions; a second group is a second
    /// declaration.
    ///
    /// - Parameters:
    ///   - side: the edge of the bar the group stands at.
    ///   - order: where the group stands among the others at its edge, lower
    ///     earlier in reading order; equal ones keep what is declared around
    ///     them in place.
    ///   - items: the group's actions, in reading order.
    public func toolbar(
        _ side: ToolbarSide = .trailing, order: Int = 0, @ToolbarBuilder _ items: () -> [ToolbarItem]
    ) -> Modified {
        toolbarGroup(side, id: nil, order: order, items())
    }

    /// Actions joining the group of the same `id` declared around this page -
    /// sharing its background - or starting it, where no group has the id yet.
    ///
    ///     // the window's page
    ///     SplitView { … } detail: { … }
    ///         .toolbar(id: "window") {
    ///             ToolbarItem("Account").onClicked { showAccount() }
    ///         }
    ///
    ///     // a page shown in it
    ///     VStack { … }
    ///         .toolbar(id: "window") {
    ///             ToolbarItem("Help").onClicked { showHelp() }
    ///         }
    ///
    /// A joined group stands where its outermost declaration puts it; the
    /// items of the declarations further in join it nearer the title. An item
    /// with the `.id()` of an item declared around it stands in that item's
    /// place while this page is shown.
    ///
    /// - Parameters:
    ///   - side: the edge of the bar a group this declaration starts stands at.
    ///   - id: the group's identity, the same across renders.
    ///   - order: where these items stand among the others joining the group,
    ///     and where a group this declaration starts stands at its edge.
    ///   - items: the actions, in reading order.
    public func toolbar(
        _ side: ToolbarSide = .trailing, id: some Hashable, order: Int = 0,
        @ToolbarBuilder _ items: () -> [ToolbarItem]
    ) -> Modified {
        toolbarGroup(side, id: String(describing: id), order: order, items())
    }

    private func toolbarGroup(_ side: ToolbarSide, id: String?, order: Int, _ items: [ToolbarItem]) -> Modified {
        modified {
            var group = Node(contract: ToolbarItemGroupContract.self, children: items.map(\.node))
            group.id = id
            group.write(ToolbarItemGroupContract.side, side)
            group.write(ToolbarItemGroupContract.order, order)

            // After the element's own children; the host finds it by type.
            // Design: docs/design/views/modifiers.md#slot-children
            $0.children.append(group)
        }
    }
}
