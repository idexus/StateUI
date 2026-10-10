// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One group of an `ItemsView`'s items, under a header and over a footer where
/// it has them.
///
///     ItemsView(groups: shelves.map { shelf in
///         Section(shelf.items) { Text($0) }
///             .id(shelf.name)
///             .header(Text(shelf.name).fontAttributes(.bold))
///     })
///
/// Each group names itself with `.id`, so two groups may hold equal items; a
/// group given none is named by its place.
public struct Section<ID: Hashable> {
    /// How many items it holds.
    let count: Int

    /// The identity of the item at a place.
    let identify: (Int) -> ID

    /// The view of the item at a place.
    let content: (Int) -> any View

    /// What the group names itself, where it was given a name.
    private(set) var name: String?

    /// Its header, where it has one.
    private(set) var header: (any View)?

    /// Its footer, where it has one.
    private(set) var footer: (any View)?

    /// A group of `items`, each its own identity, each looking as `content` says.
    public init<Items: RandomAccessCollection, Content: View>(
        _ items: Items, @ViewBuilder content: @escaping (Items.Element) -> Content
    ) where Items.Element == ID {
        self.init(items, identify: { $0 }, content: content)
    }

    /// A group of `items`, each named by the property `id`, each looking as
    /// `content` says.
    public init<Items: RandomAccessCollection, Content: View>(
        _ items: Items, id: KeyPath<Items.Element, ID>, @ViewBuilder content: @escaping (Items.Element) -> Content
    ) {
        self.init(items, identify: { $0[keyPath: id] }, content: content)
    }

    /// The group of `items`, reached by their places.
    private init<Items: RandomAccessCollection, Content: View>(
        _ items: Items, identify: @escaping (Items.Element) -> ID, content: @escaping (Items.Element) -> Content
    ) {
        let item = { (place: Int) in items[items.index(items.startIndex, offsetBy: place)] }
        count = items.count
        self.identify = { identify(item($0)) }
        self.content = { content(item($0)) }
    }

    /// The group's name, which sets its items apart from another group's.
    public func id(_ value: some Hashable) -> Self {
        var copy = self
        copy.name = String(describing: value)
        return copy
    }

    /// A view standing before the group's items.
    public func header(_ view: some View) -> Self {
        var copy = self
        copy.header = view
        return copy
    }

    /// A view standing after the group's items.
    public func footer(_ view: some View) -> Self {
        var copy = self
        copy.footer = view
        return copy
    }
}
