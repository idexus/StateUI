// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What a platform's collection holds of one ItemsView, and what it tells the tree - alike on every host: the
/// entries in order, the ones held in cells and built for them, the user's choice and opening in the list's order,
/// and the end reached.
/// Design: docs/design/host/items.md
@_spi(Host) @MainActor public final class ItemsCells {
    /// The ItemsView, while it stands in the tree: the toolkit may call its collection back after it left.
    public private(set) weak var element: MountedElement?

    private weak var runtime: HostRuntime?

    /// The entries the collection shows, as last taken.
    public private(set) var entries = ItemsEntries(sections: [])

    /// Every entry's identity in the order it shows.
    public private(set) var identities: [String] = []

    private var positions: [String: Int] = [:]
    private var itemPositions: [String: Int] = [:]
    private var held: Set<String> = []
    private var endWatch = EndReachedWatch()

    /// The cells of `element`, telling `runtime`.
    public init(_ element: MountedElement, in runtime: HostRuntime) {
        self.element = element
        self.runtime = runtime
    }

    /// Takes the entries the element carries now; the changes from the ones before, or nil where they stand.
    @discardableResult
    public func takeEntries() -> ItemsChanges? {
        let now = element?.value(.items).flatMap(ItemsEntries.init(propValue:)) ?? ItemsEntries(sections: [])
        guard now != entries else { return nil }
        let old = identities
        entries = now
        identities = now.identities
        positions = Dictionary(identities.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        itemPositions = [:]
        for (position, identity) in now.sections.flatMap(\.items).enumerated() {
            itemPositions[identity] = position
        }
        held = held.filter { positions[$0] != nil }
        return ItemsChanges(from: old, to: identities)
    }

    /// Down, across or in columns.
    public var layout: ItemsLayout {
        element?.value(.itemsLayout).flatMap(ItemsLayout.init(propValue:)) ?? .list()
    }

    /// How many items the user can choose.
    public var selectionMode: SelectionMode {
        element?.value(.selectionMode).flatMap(SelectionMode.init(propValue:)) ?? .none
    }

    /// The chosen identities, in the order they show.
    public var selected: [String] {
        element?.value(.selectedItems)?.strings ?? []
    }

    /// Whether `identity` is an item, not a header or a footer.
    public func isItem(_ identity: String) -> Bool {
        itemPositions[identity] != nil
    }

    /// The subtree of the entry of `identity`, held in a cell from now on: mounted at once where the tree can build
    /// it now, nil where it arrives with the turn under way.
    public func realize(_ identity: String) -> MountedElement? {
        if held.insert(identity).inserted { tell() }
        return item(identity)
    }

    /// The cell holding `identity` let it go: its subtree leaves the tree.
    public func release(_ identity: String) {
        if held.remove(identity) != nil { tell() }
    }

    /// The identity of a mounted entry; nil for anything else.
    public func identity(of item: MountedElement) -> String? {
        guard let element, item.parent === element, case .manual(let identity) = item.id else { return nil }
        return identity
    }

    /// The mounted subtree of `identity`, where there is one.
    public func item(_ identity: String) -> MountedElement? {
        element?.children.first { $0.id == .manual(identity) }
    }

    /// The user chose `chosen` - every item chosen now - told in the order they show; what the program selects is
    /// not the user's.
    public func userChose(_ chosen: some Sequence<String>) {
        guard !ProgramWrite.isWriting else { return }
        let ordered = Set(chosen).filter(isItem).sorted { positions[$0, default: 0] < positions[$1, default: 0] }
        guard ordered != selected, let element, let runtime else { return }
        element.send(.selectionChanged, [.strings(ordered)], in: runtime)
    }

    /// The user opened the item of `identity`.
    public func userActivated(_ identity: String) {
        guard isItem(identity), let element, let runtime else { return }
        element.send(.itemActivated, [.string(identity)], in: runtime)
    }

    /// The entries in view now: the end is told reached as the last item among them comes near the last of all.
    public func showing(_ inView: some Sequence<String>) {
        guard let element, let runtime, element.handler(.endReached) != nil else { return }
        let last = inView.compactMap { itemPositions[$0] }.max() ?? -1
        let within = element.value(.endReachedWithin)?.number.map { Int($0) } ?? 0
        guard endWatch.reached(count: itemPositions.count, last: last, within: within) else { return }
        element.send(.endReached, [], in: runtime)
    }

    /// Tells the tree which entries the cells hold, in the order they show.
    private func tell() {
        guard let element, let runtime else { return }
        let ordered = held.sorted { positions[$0, default: 0] < positions[$1, default: 0] }
        element.send(.realizedChanged, [.strings(ordered)], in: runtime)
    }
}
