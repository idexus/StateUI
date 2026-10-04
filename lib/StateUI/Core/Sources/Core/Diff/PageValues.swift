// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a view says of the page it stands on - its title, its background, the phases it hears - as a page's node of
/// values, channels and handlers, held apart from the view's own: a page's `background` never meets the view's. The
/// page the view stands on takes them (Differ+Element.swift). Never changed once made, so a copied view shares
/// nothing with the one it came from.
/// Design: docs/design/views/pages.md#what-a-view-says-of-its-page
final class PageValues {
    /// The values: a `PageContract` node's properties, channels and handlers.
    let node: Node

    init(_ node: Node) {
        self.node = node
    }

    /// These values with `written` over them - what is written on a composed view over what its body says.
    func merged(under written: PageValues) -> PageValues {
        var node = self.node
        node.props.merge(written.node.props) { _, wrote in wrote }
        node.driven.merge(written.node.driven) { _, wrote in wrote }

        for (name, handler) in written.node.events.sorted(by: { $0.key < $1.key }) {
            node.addHandler(name, handler)
        }

        return PageValues(node)
    }
}

extension Node {
    /// Takes what the view a page shows says of the page: its values, channels and handlers.
    mutating func take(_ values: PageValues) {
        props.merge(values.node.props) { _, said in said }
        driven.merge(values.node.driven) { _, said in said }

        for (name, handler) in values.node.events.sorted(by: { $0.key < $1.key }) {
            addHandler(name, handler)
        }
    }

    /// Takes, as an arrangement standing where a page stands, the title and the icon `values` give; anything else
    /// a page alone says, and anywhere but at a page's position nothing, is complained about.
    mutating func takeAsArrangement(_ values: PageValues) {
        let own = Set(PageElementContract.members.map(\.name))
        let said = Set(values.node.props.keys.map(\.name)).union(values.node.driven.keys.map(\.name))
            .union(values.node.events.keys.map(\.name))

        guard NodeType.arrangements.contains(type) else {
            complain("""
                \(said.sorted().joined(separator: ", ")) says something of a page, written on a view no page shows: \
                it says nothing there. Write it on the view a page shows - a window's, a stack's root or \
                destination, a tab, a sheet.
                """)
            return
        }

        for (key, value) in values.node.props where own.contains(key.name) { props[key] = value }
        for (key, value) in values.node.driven where own.contains(key.name) { driven[key] = value }

        let others = said.subtracting(own)
        if !others.isEmpty {
            complain("""
                \(others.sorted().joined(separator: ", ")) says something of a page, written on \(type.name), which \
                stands where a page stands as a page already and takes only a title and an icon.
                """)
        }
    }
}

/// A page's values as modifiers write them - every way a view's own property is written, kept to the page.
struct PageValuesWriter: PropertyContainer {
    var node: Node

    func modified(_ change: (inout Node) -> Void) -> PageValuesWriter {
        var copy = self
        change(&copy.node)
        return copy
    }
}

extension View {
    /// This view, saying `change` of the page it stands on.
    func pageSays(_ change: (PageValuesWriter) -> PageValuesWriter) -> Modified {
        modified { node in
            let written = PageValuesWriter(node: node.pageValues?.node ?? Node(contract: PageContract.self))
            node.pageValues = PageValues(change(written).node)
        }
    }
}
