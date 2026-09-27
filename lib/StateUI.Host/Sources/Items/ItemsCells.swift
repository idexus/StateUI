// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A cell of a platform's collection, as the host layer holds it to the entry it shows.
@_spi(Host) @MainActor public protocol ItemsHolding: AnyObject {
    /// The identity the cell holds, where it holds one.
    var identity: String? { get }

    /// The entry whose subtree the cell shows, where it shows one.
    var shown: MountedElement? { get }

    /// Holds the entry of `identity`, showing `item`'s subtree, or nothing until it is built.
    func hold(_ identity: String, _ item: MountedElement?)

    /// Holds nothing, and shows nothing.
    func letGo()
}

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

    /// The one cell holding each entry: a subtree stands in one cell at a time.
    private var holders: [String: any ItemsHolding] = [:]

    /// The entries the tree was last told to build: those within reach of the cells.
    private var built: Set<String> = []

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
        built = built.filter { positions[$0] != nil }
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

    // MARK: - The cells

    /// The collection asked `holding` for the entry of `identity`: the cell takes it - from a cell before, which
    /// then shows nothing - and its subtree: one built within reach of the cells, else built now with those within
    /// reach where the tree can build it, else with the turn under way.
    /// Design: docs/design/host/items.md#one-cell-an-entry
    public func hold(_ identity: String, in holding: any ItemsHolding) {
        if let previous = holding.identity, previous != identity { letGo(previous, from: holding) }
        if let other = holders[identity], other !== holding { other.letGo() }
        holders[identity] = holding
        held.insert(identity)
        if !built.contains(identity) { tell() }
        let item = item(identity)
        if holding.identity != identity || holding.shown !== item { holding.hold(identity, item) }
    }

    /// `holding` comes on screen showing the entry of `identity`: a collection shows again, without asking for it, a
    /// cell that ended showing the entry a moment before and let it go - the cell takes it again.
    public func show(_ identity: String, in holding: any ItemsHolding) {
        guard holders[identity] !== holding || holding.identity != identity || holding.shown == nil else { return }
        hold(identity, in: holding)
    }

    /// `holding` ended showing its entry, which no cell holds then where no other cell took it since; the tree lets
    /// it go once the cells move out of its reach.
    public func endShowing(in holding: any ItemsHolding) {
        guard let identity = holding.identity else { return }
        letGo(identity, from: holding)
    }

    /// The tree's entries changed: every cell shows the subtree its entry has now - one built with the turn under
    /// way, or built again after the one before was let go. Answers the cells that took another.
    @discardableResult
    public func childrenChanged() -> [any ItemsHolding] {
        var changed: [any ItemsHolding] = []
        for (identity, holding) in holders.sorted(by: { $0.key < $1.key }) where holding.identity == identity {
            let item = item(identity)
            guard holding.shown !== item else { continue }
            holding.hold(identity, item)
            changed.append(holding)
        }
        return changed
    }

    /// The cell holding the entry of `identity`, where one does.
    public func holding(of identity: String) -> (any ItemsHolding)? {
        guard let holding = holders[identity], holding.identity == identity else { return nil }
        return holding
    }

    /// `holding` lets the entry of `identity` go; the cells no longer hold it only where that cell still owns it.
    private func letGo(_ identity: String, from holding: any ItemsHolding) {
        if holding.identity == identity { holding.letGo() }
        guard holders[identity] === holding else { return }
        holders[identity] = nil
        held.remove(identity)
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

    /// The user tapped the item of `identity`, where the toolkit's collection decides nothing of a tap (`ItemsTap`).
    public func userTapped(_ identity: String) {
        guard isItem(identity) else { return }
        let tap = ItemsTap(on: identity, mode: selectionMode, chosen: selected)
        if let chosen = tap.chosen { userChose(chosen) }
        if tap.opens { userActivated(identity) }
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

    /// Tells the tree to build the entries within reach of the cells, in the order they show: as many before and
    /// after each cell as the cells hold, eight at least.
    /// Design: docs/design/host/items.md#within-reach
    private func tell() {
        guard let element, let runtime else { return }
        let reach = max(8, held.count)
        var within: [String] = []
        var end = -1
        for place in held.compactMap({ positions[$0] }).sorted() {
            let first = max(place - reach, end + 1)
            let last = min(place + reach, identities.count - 1)
            guard first <= last else { continue }
            within += identities[first...last]
            end = last
        }
        built = Set(within)
        element.send(.realizedChanged, [.strings(within)], in: runtime)
    }
}
