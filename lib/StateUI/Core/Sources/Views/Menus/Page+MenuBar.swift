// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

extension PropertyContainer where Self: Page {
    /// Menus on the menu bar while the page this stands in is shown, declared
    /// where the state they follow lives.
    ///
    ///     VStack { … }
    ///         .menuBar {
    ///             Menu("File") {
    ///                 MenuItem("Save").id("save").onClicked { save() }
    ///                 MenuItem("Export…").onClicked { export() }
    ///             }
    ///             .id(StandardMenu.file)
    ///         }
    ///
    /// The menus are built with the body declaring them, so an entry follows
    /// the state it reads. Declared on a `NavigationStack`, a `TabbedView`, a
    /// `SplitView` or a window's page, they stand on every page shown in it.
    /// A menu with the `.id()` of a menu declared around it joins that menu:
    /// its entries stand after the others as a section of their own, and an
    /// entry with the `.id()` of an entry there stands in that entry's place
    /// while this page is shown. Other menus follow those declared around
    /// them, before the platform's Window and Help. Android puts the menus
    /// behind the overflow of the page's stack's bar; an iPhone shows none.
    ///
    /// - Parameters:
    ///   - order: where these menus and sections stand among the others, lower
    ///     earlier; equal ones keep what is declared around them first.
    ///   - menus: the menus, in order.
    public func menuBar(order: Int = 0, @MenuBarBuilder _ menus: () -> [Menu]) -> Modified {
        let menus = menus()
        return modified {
            var bar = Node(contract: MenuBarContract.self, children: menus.map(\.node))
            bar.write(MenuBarContract.order, order)

            // After the element's own children; the host finds it by type.
            // Design: docs/design/views/modifiers.md#slot-children
            $0.children.append(bar)
        }
    }
}
