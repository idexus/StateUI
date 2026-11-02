// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What builds the view of one entry of an ItemsView, whatever its items' type.
@MainActor
protocol ItemsViews: AnyObject {
    /// The view of the entry of `identity`; nil where the list shows none.
    func view(for identity: String) -> (any View)?
}

/// What one build of an ItemsView holds: its sections, every identity they show
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
        case sectionHeader(Int)
        case sectionFooter(Int)
        case item(Int, Int)
    }

    private let sections: [Section<ID>]
    private let sectioned: Bool
    private var header: (any View)?
    private var footer: (any View)?
    private var finished = false

    /// Every identity, in the order it shows.
    private(set) var entries = ItemsEntries(sections: [])

    private var places: [String: Place] = [:]
    private var order: [String: Int] = [:]
    private var ordered: [String] = []
    private var identities: [ID: [String]] = [:]

    /// The source of `sections`; a list with no sections is one section standing for none.
    init(sections: [Section<ID>], sectioned: Bool) {
        self.sections = sections
        self.sectioned = sectioned
    }

    /// Takes the list's own header and footer and names every entry - once for
    /// the source, however often the view is built from it: an item by its
    /// value, under the identity `book` says it stood under while it stays on
    /// the list, a new one under its words, told apart from any other's.
    /// Design: docs/design/views/items.md#identities-in-order
    func finish(header: (any View)?, footer: (any View)?, book: ItemsBook<ID>) {
        guard !finished else { return }
        finished = true
        self.header = header
        self.footer = footer

        var names: Set<String> = []
        let titled = sections.enumerated().map { number, section in
            (number, section, uniqueName(Self.words(section.name ?? String(number)), among: &names))
        }
        // What every value standing again stood under, kept for it before any new value is named.
        var kept: [ItemsBook<ID>.Key: String] = [:]
        for (_, section, name) in titled {
            for place in 0..<section.count {
                let key = ItemsBook<ID>.Key(section: name, id: section.identify(place))
                if kept[key] == nil, let earlier = book.identities[key] { kept[key] = earlier }
            }
        }
        let reserved = Set(kept.values)

        var built: [ItemsEntries.Section] = []
        var stood: [ItemsBook<ID>.Key: String] = [:]
        for (number, section, name) in titled {
            var items: [String] = []
            for place in 0..<section.count {
                let id = section.identify(place)
                let key = ItemsBook<ID>.Key(section: name, id: id)
                let identity: String
                if stood[key] == nil, let earlier = kept[key] {
                    identity = earlier
                } else {
                    let words = Self.words(String(describing: id))
                    let written = sectioned ? name + "\u{1F}" + words : words
                    Renderer.shared.texts += 1
                    if stood[key] != nil {
                        complain("an ItemsView holds the same item twice, \"\(written)\"; give each its own identity")
                    }
                    identity = free(written, avoiding: reserved)
                }
                stood[key] = stood[key] ?? identity
                places[identity] = .item(number, place)
                identities[id, default: []].append(identity)
                items.append(identity)
            }
            built.append(ItemsEntries.Section(
                name,
                header: section.header.map { _ in named(name + "\u{1E}header", .sectionHeader(number)) },
                footer: section.footer.map { _ in named(name + "\u{1E}footer", .sectionFooter(number)) },
                items: items))
        }
        entries = ItemsEntries(
            header: header.map { _ in named("\u{1E}header", .header) },
            footer: footer.map { _ in named("\u{1E}footer", .footer) },
            sections: built)

        ordered = entries.identities
        for (position, identity) in ordered.enumerated() {
            order[identity] = position
        }
        book.identities = stood
    }

    /// A section's `name`, told apart from one `names` holds already, and held.
    private func uniqueName(_ name: String, among names: inout Set<String>) -> String {
        var told = name
        if names.contains(name) {
            complain("two sections of an ItemsView are named \"\(name)\"; give each its own name")
            var variant = 1
            while names.contains("\(name)\u{1D}\(variant)") { variant += 1 }
            told = "\(name)\u{1D}\(variant)"
        }
        names.insert(told)
        return told
    }

    /// `identity`, or the first of its variants no entry stands under and no value standing again keeps.
    private func free(_ identity: String, avoiding reserved: Set<String> = []) -> String {
        guard places[identity] != nil || reserved.contains(identity) else { return identity }
        var variant = 1
        while places["\(identity)\u{1D}\(variant)"] != nil || reserved.contains("\(identity)\u{1D}\(variant)") {
            variant += 1
        }
        return "\(identity)\u{1D}\(variant)"
    }

    /// Words as an identity carries them: a NUL, where a C string ends, as U+FFFD.
    /// Design: docs/design/views/items.md#identities-in-order
    private static func words(_ text: String) -> String {
        guard text.unicodeScalars.contains("\u{0}") else { return text }
        return String(String.UnicodeScalarView(text.unicodeScalars.map { $0 == "\u{0}" ? "\u{FFFD}" : $0 }))
    }

    /// `identity` standing at `place`.
    private func named(_ identity: String, _ place: Place) -> String {
        Renderer.shared.texts += 1
        let identity = free(identity)
        places[identity] = place
        return identity
    }

    func view(for identity: String) -> (any View)? {
        switch places[identity] {
        case .header: header
        case .footer: footer
        case .sectionHeader(let section): sections[section].header
        case .sectionFooter(let section): sections[section].footer
        case .item(let section, let place): sections[section].content(place)
        case nil: nil
        }
    }

    /// The item an identity names; nil for a header, a footer or none.
    func id(for identity: String) -> ID? {
        guard case .item(let section, let place) = places[identity] else { return nil }
        return sections[section].identify(place)
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
        AnyView(node: (source.view(for: identity) ?? VStack {}).node)
    }
}

/// What a list knows of its items across its builds: the identity each value stood under, kept while the value stays
/// on the list - so a value keeps its identity as the order changes, whatever its words.
/// Design: docs/design/views/items.md#identities-in-order
final class ItemsBook<ID: Hashable> {
    /// A value in the section it stands in.
    struct Key: Hashable {
        let section: String
        let id: ID
    }

    /// The identity each value stood under in the last build.
    var identities: [Key: String] = [:]
}
