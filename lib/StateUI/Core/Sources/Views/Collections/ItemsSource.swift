// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What builds the view of one entry of an ItemsView, whatever its items' type.
protocol ItemsViews: AnyObject {
    /// The view of the entry of `identity`; nil where the list shows none.
    func view(for identity: String) -> (any View)?
}

/// What one build of an ItemsView holds: its groups, every identity they show
/// in order, and how each entry is made. A new one for every build its parent
/// makes; the same one while only the host's cells change, so an entry built
/// from it is carried whole.
/// Design: docs/design/views/items.md#a-source-a-build
final class ItemsSource<Items: RandomAccessCollection, Id: Hashable>: ItemsViews {
    /// Where an identity stands.
    private enum Place {
        case header
        case footer
        case groupHeader(Int)
        case groupFooter(Int)
        case item(Int, Items.Index)
    }

    private let groups: [ItemsGroup<Items, Id>]
    private let grouped: Bool
    private var header: (any View)?
    private var footer: (any View)?
    private var finished = false

    /// Every identity, in the order it shows.
    private(set) var entries = ItemsEntries(sections: [])

    private var places: [String: Place] = [:]
    private var order: [String: Int] = [:]
    private var identities: [Id: [String]] = [:]

    /// The source of `groups`; a list with no groups is one group standing for none.
    init(groups: [ItemsGroup<Items, Id>], grouped: Bool) {
        self.groups = groups
        self.grouped = grouped
    }

    /// Takes the list's own header and footer and names every entry - once for
    /// the source, however often the view is built from it.
    /// Design: docs/design/views/items.md#identities-in-order
    func finish(header: (any View)?, footer: (any View)?) {
        guard !finished else { return }
        finished = true
        self.header = header
        self.footer = footer

        var sections: [ItemsEntries.Section] = []
        for (number, group) in groups.enumerated() {
            let name = group.name ?? String(number)
            var items: [String] = []
            for index in group.items.indices {
                let id = group.identify(group.items[index])
                let written = grouped ? name + "\u{1F}" + String(describing: id) : String(describing: id)
                let identity = unique(written)
                places[identity] = .item(number, index)
                identities[id, default: []].append(identity)
                items.append(identity)
            }
            sections.append(ItemsEntries.Section(
                header: group.header.map { _ in named(name + "\u{1E}header", .groupHeader(number)) },
                footer: group.footer.map { _ in named(name + "\u{1E}footer", .groupFooter(number)) },
                items: items))
        }
        entries = ItemsEntries(
            header: header.map { _ in named("\u{1E}header", .header) },
            footer: footer.map { _ in named("\u{1E}footer", .footer) },
            sections: sections)

        for (position, identity) in entries.identities.enumerated() {
            order[identity] = position
        }
    }

    /// `identity`, told apart from an equal one before it the way a repeated
    /// `.id()` is.
    private func unique(_ identity: String) -> String {
        guard places[identity] != nil else { return identity }
        complain("two items of an ItemsView describe as \"\(identity)\"; give each its own identity")
        var variant = 1
        while places["\(identity)\u{0}\(variant)"] != nil { variant += 1 }
        return "\(identity)\u{0}\(variant)"
    }

    /// `identity` standing at `place`.
    private func named(_ identity: String, _ place: Place) -> String {
        let identity = unique(identity)
        places[identity] = place
        return identity
    }

    func view(for identity: String) -> (any View)? {
        switch places[identity] {
        case .header: header
        case .footer: footer
        case .groupHeader(let group): groups[group].header
        case .groupFooter(let group): groups[group].footer
        case .item(let group, let index): groups[group].content(groups[group].items[index])
        case nil: nil
        }
    }

    /// The item an identity names; nil for a header, a footer or none.
    func id(for identity: String) -> Id? {
        guard case .item(let group, let index) = places[identity] else { return nil }
        return groups[group].identify(groups[group].items[index])
    }

    /// Every identity holding one of `ids`, in the order they show.
    func identities(of ids: some Sequence<Id>) -> [String] {
        ids.flatMap { identities[$0] ?? [] }.sorted { (order[$0] ?? 0) < (order[$1] ?? 0) }
    }

    /// The entries the host holds in its cells, each its own view, in the order
    /// they show; an identity the list no longer shows is left out.
    func children(realized: [String]) -> [Node] {
        realized.filter { places[$0] != nil }
            .sorted { (order[$0] ?? 0) < (order[$1] ?? 0) }
            .map { identity in
                var node = ItemsEntry(identity: identity, source: self).node
                node.id = identity
                return node
            }
    }
}

/// One entry of an ItemsView, built as a view of its own - with its own reads, so
/// a state it reads builds it alone - and carried whole while its source is the
/// same.
struct ItemsEntry: View {
    let identity: String
    let source: any ItemsViews

    var body: some View {
        // Chosen by identity, so held as `any View` and handed on as its node.
        ModifiedContent(node: (source.view(for: identity) ?? VStack {}).node)
    }
}
