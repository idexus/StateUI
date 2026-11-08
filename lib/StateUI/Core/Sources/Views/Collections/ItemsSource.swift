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
    private var header: (any View)?
    private var footer: (any View)?
    private var finished = false

    /// Every identity, in the order it shows.
    private(set) var entries = ItemsEntries(sections: [])

    private var places: [String: Place] = [:]
    private var order: [String: Int] = [:]
    private var ordered: [String] = []
    private var identities: [ID: String] = [:]

    /// The source of `sections`; a list with no sections is one section standing for none.
    init(sections: [Section<ID>]) {
        self.sections = sections
    }

    /// A source of the same sections, not yet finished: a list given a header or a footer builds from its own.
    /// Design: docs/design/views/items.md#a-source-a-build
    func again() -> ItemsSource {
        ItemsSource(sections: sections)
    }

    /// Names every entry once for the source: an existing occurrence keeps its token; a new string takes a free
    /// name, and another value takes an allocated token. The book preserves them across builds.
    /// Design: docs/design/views/items.md#identities-in-order
    func finish(header: (any View)?, footer: (any View)?, book: ItemsBook<ID>) {
        guard !finished else { return }
        finished = true
        self.header = header
        self.footer = footer

        let names = sectionNames(book: book)
        let reserved = Set(book.items.values.flatMap { $0 })
        var stood: [ID: [String]] = [:]

        var built: [ItemsEntries.Section] = []
        for (number, section) in sections.enumerated() {
            var items: [String] = []
            for place in 0..<section.count {
                let id = section.identify(place)
                let occurrence = stood[id]?.count ?? 0
                if occurrence > 0 {
                    complain("an ItemsView holds the same item twice, \"\(Self.words(String(describing: id)))\"; give each its own identity")
                }
                let identity: String
                if let earlier = book.items[id], earlier.indices.contains(occurrence) {
                    identity = earlier[occurrence]
                } else {
                    let proposed = stood[id]?.first ?? (id as? String).map { Self.words($0) } ?? book.item()
                    identity = free(proposed, avoiding: reserved)
                }
                stood[id, default: []].append(identity)
                identities[id] = identities[id] ?? identity
                places[identity] = .item(number, place)
                items.append(identity)
            }
            let name = names[number]
            built.append(ItemsEntries.Section(
                name,
                header: section.header.map { _ in named("\u{1E}\(name)\u{1E}header", .sectionHeader(number)) },
                footer: section.footer.map { _ in named("\u{1E}\(name)\u{1E}footer", .sectionFooter(number)) },
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
        book.items = stood
    }

    /// Each section's token, kept by id and occurrence. An unkeyed section uses its position; every new name is
    /// kept apart from those of the build before, including sections that are leaving.
    private func sectionNames(book: ItemsBook<ID>) -> [String] {
        let keys = sections.enumerated().map { number, section in
            section.identity ?? AnyHashable(SectionPlace(number))
        }
        let reserved = Set(book.sections.values.flatMap { $0 })
        var stood: [AnyHashable: [String]] = [:]
        var names: [String] = []
        for (number, key) in keys.enumerated() {
            let occurrence = stood[key]?.count ?? 0
            if occurrence > 0 {
                complain("two sections of an ItemsView share the id \"\(Self.words(String(describing: key.base)))\"; give each its own")
            }
            let name: String
            if let earlier = book.sections[key], earlier.indices.contains(occurrence) {
                name = earlier[occurrence]
            } else {
                let proposed = stood[key]?.first ?? sections[number].identity.map {
                    ($0.base as? String).map { Self.words($0) } ?? book.section()
                } ?? String(number)
                name = Self.variant(of: proposed) { names.contains($0) || reserved.contains($0) }
            }
            stood[key, default: []].append(name)
            names.append(name)
        }
        book.sections = stood
        return names
    }

    /// `identity`, or the first of its variants no entry stands under and the build before kept from a new value.
    private func free(_ identity: String, avoiding reserved: Set<String>) -> String {
        Self.variant(of: identity) { places[$0] != nil || reserved.contains($0) }
    }

    /// `words`, or the first of its variants - the words, a group separator and a number - that `taken` lets stand.
    private static func variant(of words: String, taken: (String) -> Bool) -> String {
        guard taken(words) else { return words }
        var variant = 1
        while taken("\(words)\u{1D}\(variant)") { variant += 1 }
        return "\(words)\u{1D}\(variant)"
    }

    /// An authored string with NUL and the list's reserved separators replaced by U+FFFD.
    /// Design: docs/design/views/items.md#identities-in-order
    private static func words(_ text: String) -> String {
        Renderer.shared.texts += 1
        guard text.unicodeScalars.contains(where: isReserved) else { return text }
        return String(String.UnicodeScalarView(text.unicodeScalars.map { isReserved($0) ? "\u{FFFD}" : $0 }))
    }

    /// Whether `scalar` is one no words carry: a NUL, a group separator or a record separator.
    private static func isReserved(_ scalar: Unicode.Scalar) -> Bool {
        scalar == "\u{0}" || scalar == "\u{1D}" || scalar == "\u{1E}"
    }

    /// `identity` - a name of the list's own, which no words equal - standing at `place`.
    private func named(_ identity: String, _ place: Place) -> String {
        Renderer.shared.texts += 1
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

    /// The identity of each of `ids` the list holds, in the order they show: one a value, where it stands first.
    func identities(of ids: some Sequence<ID>) -> [String] {
        ids.compactMap { identities[$0] }.sorted { (order[$0] ?? 0) < (order[$1] ?? 0) }
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

/// What a section given no id is known by: its place, which no author's id equals.
private struct SectionPlace: Hashable {
    let number: Int

    init(_ number: Int) { self.number = number }
}
