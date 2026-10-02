// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

extension PropertyContainer where Self: Page {
    /// A view on the bar in place of the page's title, declared where the
    /// state it follows lives.
    ///
    ///     List { … }
    ///         .titleView {
    ///             SearchField($query).placeholder("Search")
    ///         }
    ///
    /// An ordinary part of the tree: a composed view there reads its own
    /// state, and a binding handed to a control keeps it live. Declared around
    /// the page - on its stack or its window's page - it stands in every page's
    /// title shown there that declares none of its own; the innermost
    /// declaration wins.
    ///
    /// - Parameter content: one view - an `if`/`else` is one; put several
    ///   controls in a layout.
    public func titleView<Content: View>(@ViewBuilder _ content: () -> Content) -> Modified {
        let view = content().node
        return modified {
            // After the element's own children; the host finds it by type.
            // Design: docs/design/views/modifiers.md#slot-children
            $0.children.append(Node(contract: TitleViewContract.self, children: [view]))
        }
    }
}
