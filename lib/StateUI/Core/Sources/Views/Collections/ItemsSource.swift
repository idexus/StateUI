// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What builds the view of one entry of an ItemsView, whatever its items' type.
@MainActor
protocol ItemsViews: AnyObject {
    /// The view of the entry of `identity`; nil where the list shows none.
    func view(for identity: String) -> (any View)?
}

/// What one build of an ItemsView holds: its groups, every identity they show
/// in order, and how each entry is made. A new one for every build its parent
/// makes; the same one while only the host's cells change, so an entry built
/// from it is carried whole.
/// Design: docs/design/views/items.md#a-source-a-build
@MainActor
final class ItemsSource<ID: Hashable>: ItemsViews {
    /// Where an identity stands.
    private enum Place {
        case header
        case footer
        case groupHeader(Int)
        case groupFooter(Int)
        case item(Int, Int)
    }

    private let groups: [Section<ID>]
    private let grouped: Bool
    private var header: (any View)?
    private var footer: (any View)?
    private var finished = false

    /// Every identity, in the order it shows.
    private(set) var entries = ItemsEntries(sections: [])

    private var places: [String: Place] = [:]
    private var order: [String: Int] = [:]
    private var ordered: [String] = []
    private var identities: [ID: [String]] = [:]

    /// The source of `groups`; a list with no groups is one group standing for none.
    init(groups: [Section<ID>], grouped: Bool) {
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
        var names: Set<String> = []
        for (number, group) in groups.enumerated() {
            let name = uniqueName(group.name ?? String(number), among: &names)
            var items: [String] = []
            for place in 0..<group.count {
                let id = group.identify(place)
                let written = grouped ? name + "\u{1F}" + String(describing: id) : String(describing: id)
                Renderer.shared.texts += 1
                let identity = unique(written)
                places[identity] = .item(number, place)
                identities[id, default: []].append(identity)
                items.append(identity)
            }
            sections.append(ItemsEntries.Section(
                name,
                header: group.header.map { _ in named(name + "\u{1E}header", .groupHeader(number)) },
                footer: group.footer.map { _ in named(name + "\u{1E}footer", .groupFooter(number)) },
                items: items))
        }
        entries = ItemsEntries(
            header: header.map { _ in named("\u{1E}header", .header) },
            footer: footer.map { _ in named("\u{1E}footer", .footer) },
            sections: sections)

        ordered = entries.identities
        for (position, identity) in ordered.enumerated() {
            order[identity] = position
        }
    }

    /// A group's `name`, told apart from one `names` holds already, and held.
    private func uniqueName(_ name: String, among names: inout Set<String>) -> String {
        var told = name
        if names.contains(name) {
            complain("two groups of an ItemsView are named \"\(name)\"; give each its own name")
            var variant = 1
            while names.contains("\(name)\u{0}\(variant)") { variant += 1 }
            told = "\(name)\u{0}\(variant)"
        }
        names.insert(told)
        return told
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
        Renderer.shared.texts += 1
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
        case .item(let group, let place): groups[group].content(place)
        case nil: nil
        }
    }

    /// The item an identity names; nil for a header, a footer or none.
    func id(for identity: String) -> ID? {
        guard case .item(let group, let place) = places[identity] else { return nil }
        return groups[group].identify(place)
    }

    /// Every identity holding one of `ids`, in the order they show.
    func identities(of ids: some Sequence<ID>) -> [String] {
        ids.flatMap { identities[$0] ?? [] }.sorted { (order[$0] ?? 0) < (order[$1] ?? 0) }
    }

    /// The positions `identities` stand at in this build.
    func positions(of identities: [String]) -> [Int] {
        identities.compactMap { order[$0] }
    }

    /// The entries within `reach` of the host's cells, each its own view, in
    /// the order they show: the ones it said, and the ones standing now where
    /// those stood. An identity the list no longer shows is left out.
    /// Design: docs/design/views/items.md#built-when-a-cell-asks
    func children(within reach: ItemsReach) -> [Node] {
        let standing = reach.positions.compactMap { ordered.indices.contains($0) ? ordered[$0] : nil }
        return Set(reach.identities + standing).filter { places[$0] != nil }
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
/// same: one value to compare, which every render of the list compares for each
/// entry it keeps.
struct ItemsEntry: View, @MainActor Equatable {
    let identity: String
    let source: any ItemsViews

    static func == (lhs: ItemsEntry, rhs: ItemsEntry) -> Bool {
        lhs.identity == rhs.identity && lhs.source === rhs.source
    }

    var body: some View {
        // Chosen by identity, so held as `any View` and handed on as its node.
        ModifiedContent(node: (source.view(for: identity) ?? VStack {}).node)
    }
}
