// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Items shown by the platform's own collection - as many as you like, since
/// only the ones near what the platform holds are built.
///
///     @State private var chosen: String?
///
///     ItemsView(files, id: \.path) { file in
///         Text(file.name).padding(horizontal: 14, vertical: 10)
///     }
///     .selection($chosen)
///     .onItemActivated { path in open(path) }
///
/// Each item is built as the platform's collection comes near it, as a view of
/// its own: a state it reads builds that item alone, and a state it declares
/// lives while the item stays near what the platform holds. The platform scrolls, reuses its cells, lets
/// the user choose and open items, and tells assistive technology about them.
///
/// An item is known by its identity's value, independently of its description;
/// each value stands once in a list. The host receives a token the list keeps for that value.
public struct ItemsView<ID: Hashable>: View, FocusElement {
    /// The items, their identities and their views - one source a build.
    private var source: ItemsSource<ID>

    /// The entries within reach of the host's cells, as it last said.
    @State private var reach = ItemsReach()

    /// The identity each item stood under, kept for it while it stays on the list.
    @State private var book = ItemsBook<ID>()

    private var layout = ItemsLayout.list()
    private var headerView: (any View)?
    private var footerView: (any View)?
    private var empty: (any View)?
    private var choice: Choice?
    private var selected: [Handler] = []
    private var activated: [ValueHandler<ID>] = []
    private var endReached: (within: Int, handlers: [Handler])?
    private var aimed: Aim<Self>?

    /// What the list wears of the pull to refresh, in the order written.
    private var pull: [RefreshWorn] = []

    /// What every view's modifiers wrote on it.
    private var written = WrittenOnView()

    /// A list of `items`, each its own identity, each looking as `content` says.
    public init<Items: RandomAccessCollection, Content: View>(
        _ items: Items, @ViewBuilder content: @escaping (Items.Element) -> Content
    ) where Items.Element == ID {
        source = ItemsSource(sections: [Section(items, content: content)])
    }

    /// A list of `items`, each named by the property `id`, each looking as
    /// `content` says.
    public init<Items: RandomAccessCollection, Content: View>(
        _ items: Items, id: KeyPath<Items.Element, ID>, @ViewBuilder content: @escaping (Items.Element) -> Content
    ) {
        source = ItemsSource(sections: [Section(items, id: id, content: content)])
    }

    /// A list of sections, each under its header and over its footer.
    public init(sections: [Section<ID>]) {
        source = ItemsSource(sections: sections)
    }

    /// The platform's collection - or, while there are no items, the empty
    /// view in its place.
    public var body: some View {
        source.finish(header: headerView, footer: footerView, book: book)
        // The empty view is held as `any View`, so both answers go as nodes; it stands in a scroller keeping the pull.
        if source.entries.isEmpty, let empty {
            guard !pull.isEmpty else { return AnyView(empty) }
            let scroller = ScrollView { AnyView(empty) }
            return AnyView(RefreshWorn.wear(pull, on: scroller))
        }

        let source = self.source
        let reach = self.reach
        let held = $reach
        var element = ItemsViewElement()
        element.node.write(ItemsViewContract.items, source.entries)
        element.node.write(ItemsViewContract.itemsLayout, layout)
        element.node.producer = { source.children(within: reach) }
        element.node.aim = aimed?.box
        aimed?.box.resolves = { [weak source] item in
            guard let source, let id = item as? ID else { return [] }
            return source.identities(of: [id])
        }

        element.node.addHandler(ItemsViewContract.realizedChanged.token) {
            guard let identities = MemberValues.carried(
                EventBuffer.current, by: ItemsViewContract.realizedChanged.name, as: [String].self)
            else { return }
            let said = ItemsReach(identities: identities, positions: source.positions(of: identities))
            guard said != held.wrappedValue else { return }

            held.wrappedValue = said
        }

        if let choice {
            element.node.write(ItemsViewContract.selectionMode, choice.mode)
            // Read as the list is described: the list is the reader, never the body that wrote it.
            element.node.readsWhenDescribed { $0.write(ItemsViewContract.selectedItems, source.identities(of: choice.chosen())) }
            element.node.addHandler(ItemsViewContract.selectedItemsChanged.token) {
                guard let identities = MemberValues.carried(
                    EventBuffer.current, by: ItemsViewContract.selectedItemsChanged.name, as: [String].self)
                else { return }

                var ids: [ID] = []
                for id in identities.compactMap({ source.id(for: $0) }) where !ids.contains(id) {
                    ids.append(id)
                }
                choice.write(ids)
            }

            for selected in selected {
                element.node.addHandler(ItemsViewContract.selectedItemsChanged.token, gate: selected.gate) {
                    guard MemberValues.carried(
                        EventBuffer.current, by: ItemsViewContract.selectedItemsChanged.name, as: [String].self) != nil
                    else { return }

                    try await selected.run()
                }
            }
        }

        for activated in activated {
            element.node.addHandler(ItemsViewContract.itemActivated.token, gate: activated.gate) {
                guard let identity = MemberValues.carried(
                    EventBuffer.current, by: ItemsViewContract.itemActivated.name, as: String.self),
                    let id = source.id(for: identity)
                else { return }

                try await activated.run(id)
            }
        }

        if let endReached {
            element.node.write(ItemsViewContract.endReachedWithin, endReached.within)
            element.node.addHandlers(ItemsViewContract.endReached.token, endReached.handlers)
        }

        return AnyView(RefreshWorn.wear(pull, on: element))
    }
}

extension ItemsView {
    /// What every view's modifiers give back: the list itself, so its own modifiers come after any of theirs.
    public typealias Modified = Self

    /// The placeholder its body is built under, with what every view's modifiers wrote on it. Assigning to it does
    /// nothing.
    public var node: Node {
        get { written.node(of: self) }
        set {}
    }

    /// A copy with one more modifier written on it.
    public func modified(_ change: (inout Node) -> Void) -> Self {
        var copy = self
        copy.written.write(change, on: Self.self)
        return copy
    }
}

extension ItemsView {
    /// A selection binding, whatever its type: how many it allows, what it
    /// holds now, and how the user's choice is written back.
    struct Choice {
        let mode: SelectionMode
        let chosen: @MainActor () -> [ID]
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
    public func selection(_ state: Binding<ID?>) -> Self {
        var copy = self
        copy.choice = Choice(
            mode: .single,
            chosen: { state.wrappedValue.map { [$0] } ?? [] },
            write: { ids in if ids.first != state.wrappedValue { state.wrappedValue = ids.first } })
        return copy
    }

    /// As many items chosen as the user likes, borrowed two-way.
    public func selection(_ state: Binding<Set<ID>>) -> Self {
        var copy = self
        copy.choice = Choice(
            mode: .multiple,
            chosen: { Array(state.wrappedValue) },
            write: { ids in if Set(ids) != state.wrappedValue { state.wrappedValue = Set(ids) } })
        return copy
    }

    /// Hears the user change what is chosen, after the selection's write: the
    /// handler reads it there. A list with no selection chooses nothing, so
    /// reports nothing.
    public func onSelectionChanged(_ handler: @escaping @MainActor () throws -> Void) -> Self {
        var copy = self
        copy.selected.append(Handler(step: handler))
        return copy
    }

    /// The same, with a handler that awaits: its `policy` says what another
    /// choice does while a run is under way.
    public func onSelectionChanged(policy: GatePolicy, _ handler: @escaping EventHandler) -> Self {
        var copy = self
        copy.selected.append(Handler(run: handler, gate: .own(policy)))
        return copy
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onSelectionChanged(gate: Gate, _ handler: @escaping EventHandler) -> Self {
        var copy = self
        copy.selected.append(Handler(run: handler, gate: .shared(gate)))
        return copy
    }

    /// Hears the user open an item - a tap on a phone, a double-click or Return
    /// on a desktop - handed its identity.
    public func onItemActivated(_ handler: @escaping @MainActor (ID) throws -> Void) -> Self {
        var copy = self
        copy.activated.append(ValueHandler(step: handler))
        return copy
    }

    /// The same, with a handler that awaits - opening a page does: its `policy`
    /// says what opening another item does while a run is under way.
    public func onItemActivated(policy: GatePolicy, _ handler: @escaping ValueEventHandler<ID>) -> Self {
        var copy = self
        copy.activated.append(ValueHandler(run: handler, gate: .own(policy)))
        return copy
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onItemActivated(gate: Gate, _ handler: @escaping ValueEventHandler<ID>) -> Self {
        var copy = self
        copy.activated.append(ValueHandler(run: handler, gate: .shared(gate)))
        return copy
    }

    /// Hears the user scroll within `within` items of the end - where more
    /// items are loaded. Every handler written hears it, within the farthest
    /// distance any of them names.
    public func onEndReached(within: Int = 0, _ handler: @escaping @MainActor () throws -> Void) -> Self {
        var copy = self
        copy.endReached = copy.reaching(within, Handler(step: handler))
        return copy
    }

    /// The same, with a handler that awaits - a load does. The end may be
    /// reached again before the items arrive: `.ignoreWhileRunning` keeps one
    /// load under way at a time.
    ///
    ///     ItemsView(rows) { … }
    ///         .onEndReached(within: 5, policy: .ignoreWhileRunning) { rows += try await nextPage() }
    public func onEndReached(within: Int = 0, policy: GatePolicy, _ handler: @escaping EventHandler) -> Self {
        var copy = self
        copy.endReached = copy.reaching(within, Handler(run: handler, gate: .own(policy)))
        return copy
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onEndReached(within: Int = 0, gate: Gate, _ handler: @escaping EventHandler) -> Self {
        var copy = self
        copy.endReached = copy.reaching(within, Handler(run: handler, gate: .shared(gate)))
        return copy
    }

    /// The end heard with `handler` after any written before it, within the farthest distance any of them names.
    private func reaching(_ within: Int, _ handler: Handler) -> (within: Int, handlers: [Handler]) {
        (max(within, endReached?.within ?? 0, 0), (endReached?.handlers ?? []) + [handler])
    }

    /// A view standing before every item, scrolled with them.
    public func header<Content: View>(@ViewBuilder _ content: () -> Content) -> Self {
        var copy = self
        copy.headerView = content()
        copy.source = source.again()
        return copy
    }

    /// A view standing after every item, scrolled with them.
    public func footer<Content: View>(@ViewBuilder _ content: () -> Content) -> Self {
        var copy = self
        copy.footerView = content()
        copy.source = source.again()
        return copy
    }

    /// A view shown in the list's place while it has no items.
    public func emptyView<Content: View>(@ViewBuilder _ content: () -> Content) -> Self {
        var copy = self
        copy.empty = content()
        return copy
    }

    /// Aims `aim` at this list, for `scroll(to:)` - an item named by the list's
    /// own identity type.
    ///
    ///     @Aim(ItemsView<Int>.self) private var list
    ///
    ///     ItemsView(0..<500) { Text("Row \($0)") }.aim(list)
    ///     Button("Top").onClicked(policy: .cancelPrevious) { try await list.scroll(to: 0, anchor: .start) }
    public func aim(_ aim: Aim<Self>) -> Self {
        var copy = self
        copy.aimed = aim
        return copy
    }
}

extension ItemsView {
    /// Runs when the user pulls the list to refresh it; the list offers the pull once it hears it - an empty one
    /// too, through the scroller its empty view stands in.
    ///
    ///     ItemsView(mail) { MailRow($0) }.onRefreshRequested { reload() }
    public func onRefreshRequested(_ handler: @escaping @MainActor () throws -> Void) -> Self {
        wearing(.requested(handler))
    }

    /// The same, with a handler that awaits - a reload does: its `policy` says what a pull does while a run is under
    /// way. The spinner shows while `isRefreshing` says so.
    ///
    ///     @State private var refreshing = false
    ///
    ///     ItemsView(mail) { MailRow($0) }
    ///         .isRefreshing($refreshing)
    ///         .onRefreshRequested(policy: .ignoreWhileRunning) {
    ///             defer { refreshing = false }
    ///             try await inbox.reload()
    ///         }
    public func onRefreshRequested(policy: GatePolicy, _ handler: @escaping EventHandler) -> Self {
        wearing(.awaited(.own(policy), handler))
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onRefreshRequested(gate: Gate, _ handler: @escaping EventHandler) -> Self {
        wearing(.awaited(.shared(gate), handler))
    }

    /// Whether the refresh is under way, both ways: the user's pull writes true into the state, and the
    /// application writes false once the items are fresh - or true, to show a refresh it began itself, which runs
    /// no `onRefreshRequested`. Without it, the spinner a pull shows goes at once.
    public func isRefreshing(_ state: Binding<Bool>) -> Self {
        wearing(.refreshing(state))
    }

    /// Whether the user can pull to refresh - by default wherever the list hears the pull; `false` withholds it
    /// while the items cannot be refreshed.
    public func isRefreshEnabled(_ value: Bool) -> Self {
        wearing(.enabled(value))
    }

    /// `isRefreshEnabled` from a state, `$x`: the host sets each new value as it stands, and no view is rebuilt
    /// for it.
    public func isRefreshEnabled(_ state: Binding<Bool>) -> Self {
        wearing(.enabledBy(state))
    }

    private func wearing(_ worn: RefreshWorn) -> Self {
        var copy = self
        copy.pull.append(worn)
        return copy
    }
}

/// The platform's collection an ItemsView stands on.
struct ItemsViewElement: ElementView, RefreshElement {
    var node = Node(contract: ItemsViewContract.self)
}
