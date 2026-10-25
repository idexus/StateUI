// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a view says of the page it stands on - its title, its background, the phases it hears - as a page's node of
/// values, channels and handlers, held apart from the view's own: a page's `background` never meets the view's. The
/// page the view stands on takes them (Differ+Element.swift). Never changed once made, so a copied view shares
/// nothing with the one it came from.
/// Design: docs/design/views/pages.md#what-a-view-says-of-its-page
@MainActor
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

        for (name, handlers) in written.node.events.sorted(by: { $0.key < $1.key }) {
            node.addHandlers(name, handlers)
        }

        return PageValues(node)
    }
}

extension Node {
    /// Takes what the view a page shows says of the page: its values, channels and handlers.
    mutating func take(_ values: PageValues) {
        props.merge(values.node.props) { _, said in said }
        driven.merge(values.node.driven) { _, said in said }

        for (name, handlers) in values.node.events.sorted(by: { $0.key < $1.key }) {
            addHandlers(name, handlers)
        }
    }

    /// Takes, as an arrangement standing where a page stands, the title, the icon and the ground of its pages `values`
    /// give; anything else a page alone says, and anywhere but at a page's position nothing, is complained about.
    mutating func takeAsArrangement(_ values: PageValues) {
        let node = values.node
        guard NodeType.arrangements.contains(type) else {
            let said = node.props.keys.map(\.name) + node.driven.keys.map(\.name) + node.events.keys.map(\.name)
            complain("""
                \(Set(said).sorted().joined(separator: ", ")) says something of a page, written on a view no page \
                shows: it says nothing there. Write it on the view a page shows - a window's, a stack's root or \
                destination, a tab, a sheet.
                """)
            return
        }

        for (key, value) in node.props where Self.pageProps.contains(key) { props[key] = value }
        for (key, value) in node.driven where Self.pageProps.contains(key) { driven[key] = value }

        let others = node.props.keys.filter { !Self.pageProps.contains($0) }.map(\.name)
            + node.driven.keys.filter { !Self.pageProps.contains($0) }.map(\.name)
            + node.events.keys.map(\.name)
        if !others.isEmpty {
            complain("""
                \(Set(others).sorted().joined(separator: ", ")) says something of a page, written on \(type.name), \
                which stands where a page stands as a page already and takes only a title, an icon and the ground of \
                its pages.
                """)
        }
    }

    /// The keys the page tier's properties - a title, an icon, a ground - are written under, made once; the tier has no
    /// event.
    private static let pageProps = Set(PageElementContract.members.map { Prop($0.name) })
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
