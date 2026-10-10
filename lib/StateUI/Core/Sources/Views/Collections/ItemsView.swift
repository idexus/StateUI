// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Items shown by the platform's own collection - as many as you like, since
/// only the ones the platform holds on screen are built.
///
///     @State private var chosen: String?
///
///     ItemsView(files, id: \.path) { file in
///         Text(file.name).padding(horizontal: 14, vertical: 10)
///     }
///     .selection($chosen)
///     .onItemActivated { path in open(path) }
///
/// Each item is built when the platform first shows it, as a view of its own:
/// a state it reads builds that item alone, and a state it declares lives
/// while the platform holds it. The platform scrolls, reuses its cells, lets
/// the user choose and open items, and tells assistive technology about them.
///
/// An item names itself by `String(describing:)` of its identity, so two items
/// must describe differently.
public struct ItemsView<Items: RandomAccessCollection, ID: Hashable>: View {
    /// The items, their identities and their views - one source a build.
    private let source: ItemsSource<Items, ID>

    /// The identities within reach of the host's cells, as it last said.
    @State private var realized: [String] = []

    private var layout = ItemsLayout.list()
    private var headerView: (any View)?
    private var footerView: (any View)?
    private var empty: (any View)?
    private var choice: Choice?
    private var activated: (gate: any Gate, handler: ValueEventHandler<ID>)?
    private var endReached: (within: Int, gate: any Gate, handler: EventHandler)?
    private var aimed: Aim<ItemsViewContract>?

    /// A list of `items`, each its own identity, each looking as `content` says.
    public init<Content: View>(_ items: Items, @ViewBuilder content: @escaping (Items.Element) -> Content)
    where Items.Element: Hashable, ID == Items.Element {
        source = ItemsSource(groups: [Section(items, content: content)], grouped: false)
    }

    /// A list of `items`, each named by the property `id`, each looking as
    /// `content` says.
    public init<Content: View>(
        _ items: Items, id: KeyPath<Items.Element, ID>, @ViewBuilder content: @escaping (Items.Element) -> Content
    ) {
        source = ItemsSource(groups: [Section(items, id: id, content: content)], grouped: false)
    }

    /// A list of groups, each under its header and over its footer.
    public init(groups: [Section<Items, ID>]) {
        source = ItemsSource(groups: groups, grouped: true)
    }

    /// The platform's collection - or, while there are no items, the empty
    /// view in its place.
    public var body: some View {
        source.finish(header: headerView, footer: footerView)
        // The empty view is held as `any View`, so both answers go as nodes.
        if source.entries.isEmpty, let empty { return ModifiedContent(node: empty.node) }

        let source = self.source
        let realized = self.realized
        let held = $realized
        var element = ItemsViewElement()
        element.node.write(ItemsViewContract.items, source.entries)
        element.node.write(ItemsViewContract.itemsLayout, layout)
        element.node.producer = { source.children(realized: realized) }
        element.node.aim = aimed?.box

        element.node.addHandler(ItemsViewContract.realizedChanged.token, gate: .none) {
            guard let identities = MemberValues.carried(
                EventBuffer.current, by: ItemsViewContract.realizedChanged.name, as: [String].self),
                identities != held.wrappedValue
            else { return }

            held.wrappedValue = identities
        }

        if let choice {
            element.node.write(ItemsViewContract.selectionMode, choice.mode)
            element.node.write(ItemsViewContract.selectedItems, source.identities(of: choice.chosen))
            element.node.addHandler(ItemsViewContract.selectedItemsChanged.token, gate: .none) {
                guard let identities = MemberValues.carried(
                    EventBuffer.current, by: ItemsViewContract.selectedItemsChanged.name, as: [String].self)
                else { return }

                var ids: [ID] = []
                for id in identities.compactMap({ source.id(for: $0) }) where !ids.contains(id) {
                    ids.append(id)
                }
                choice.write(ids)
            }
        }

        if let activated {
            element.node.addHandler(ItemsViewContract.itemActivated.token, gate: activated.gate) {
                guard let identity = MemberValues.carried(
                    EventBuffer.current, by: ItemsViewContract.itemActivated.name, as: String.self),
                    let id = source.id(for: identity)
                else { return }

                try await activated.handler(id)
            }
        }

        if let endReached {
            element.node.write(ItemsViewContract.endReachedWithin, endReached.within)
            element.node.addHandler(ItemsViewContract.endReached.token, gate: endReached.gate, endReached.handler)
        }

        return ModifiedContent(node: element.node)
    }
}

extension ItemsView {
    /// A selection binding, whatever its type: how many it allows, what it
    /// holds now, and how the user's choice is written back.
    struct Choice {
        let mode: SelectionMode
        let chosen: [ID]
        let write: ([ID]) -> Void
    }

    /// Down, across, or in columns; a list with nothing between its items
    /// where this is not said.
    ///
    ///     ItemsView(tags) { Tag($0) }.itemsLayout(.row(spacing: 8))
    public func itemsLayout(_ layout: ItemsLayout) -> Self {
        var copy = self
        copy.layout = layout
        return copy
    }

    /// One item chosen at a time, borrowed two-way: the user's choice is
    /// written here, nil where they let it go, and assigning it chooses.
    public func selection(_ binding: Binding<ID?>) -> Self {
        var copy = self
        copy.choice = Choice(
            mode: .single,
            chosen: binding.wrappedValue.map { [$0] } ?? [],
            write: { ids in if ids.first != binding.wrappedValue { binding.wrappedValue = ids.first } })
        return copy
    }

    /// As many items chosen as the user likes, borrowed two-way.
    public func selection(_ binding: Binding<Set<ID>>) -> Self {
        var copy = self
        copy.choice = Choice(
            mode: .multiple,
            chosen: Array(binding.wrappedValue),
            write: { ids in if Set(ids) != binding.wrappedValue { binding.wrappedValue = Set(ids) } })
        return copy
    }

    /// Hears the user open an item - a tap on a phone, a double-click or Return
    /// on a desktop - handed its identity.
    public func onItemActivated(_ handler: @escaping @MainActor (ID) throws -> Void) -> Self {
        onItemActivated(gate: .none) { try handler($0) }
    }

    /// The same, with a handler that awaits - opening a page does: its `gate`
    /// says what opening another item does while a run is under way.
    public func onItemActivated(gate: some Gate, _ handler: @escaping ValueEventHandler<ID>) -> Self {
        var copy = self
        copy.activated = (gate, handler)
        return copy
    }

    /// A handler that awaits passes through a gate.
    @available(*, unavailable, message: "a handler that awaits passes through a gate: .onItemActivated(gate: saving) { … } with @State var saving = SharedGate(.ignoreWhileRunning) - or gate: .none")
    public func onItemActivated(_ handler: @escaping ValueEventHandler<ID>) -> Self {
        fatalError("unavailable")
    }

    /// Hears the user scroll within `within` items of the end - where more
    /// items are loaded.
    public func onEndReached(within: Int = 0, _ handler: @escaping @MainActor () throws -> Void) -> Self {
        onEndReached(within: within, gate: .none) { try handler() }
    }

    /// The same, with a handler that awaits - a load does. The end may be
    /// reached again before the items arrive: `.ignoreWhileRunning` keeps one
    /// load under way at a time.
    ///
    ///     ItemsView(rows) { … }
    ///         .onEndReached(within: 5, gate: .ignoreWhileRunning) { rows += try await nextPage() }
    public func onEndReached(
        within: Int = 0, gate: some Gate, _ handler: @escaping EventHandler
    ) -> Self {
        var copy = self
        copy.endReached = (within: max(within, 0), gate: gate, handler: handler)
        return copy
    }

    /// A handler that awaits passes through a gate.
    @available(*, unavailable, message: "a handler that awaits passes through a gate: .onEndReached(within: n, gate: saving) { … } with @State var saving = SharedGate(.ignoreWhileRunning) - or gate: .none")
    public func onEndReached(within: Int = 0, _ handler: @escaping EventHandler) -> Self {
        fatalError("unavailable")
    }

    /// A view standing before every item, scrolled with them.
    public func header(_ view: some View) -> Self {
        var copy = self
        copy.headerView = view
        return copy
    }

    /// A view standing after every item, scrolled with them.
    public func footer(_ view: some View) -> Self {
        var copy = self
        copy.footerView = view
        return copy
    }

    /// A view shown in the list's place while it has no items.
    public func emptyView(_ view: some View) -> Self {
        var copy = self
        copy.empty = view
        return copy
    }

    /// Aims `aim` at this list, for `scrollTo`.
    ///
    ///     @Aim(ItemsViewContract.self) private var list
    ///
    ///     ItemsView(rows) { Row($0) }.aim(list)
    ///     Button("Top").onClicked(gate: .cancelPrevious) { try await list.scrollTo(rows[0], anchor: .start) }
    public func aim(_ aim: Aim<ItemsViewContract>) -> Self {
        var copy = self
        copy.aimed = aim
        return copy
    }
}

/// The platform's collection an ItemsView stands on.
struct ItemsViewElement: ElementView {
    var node = Node(contract: ItemsViewContract.self)
}
