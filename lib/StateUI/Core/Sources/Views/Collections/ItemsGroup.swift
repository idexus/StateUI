// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One group of an `ItemsView`'s items, under a header and over a footer where
/// it has them.
///
///     ItemsView(groups: shelves.map { shelf in
///         ItemsGroup(shelf.items) { Text($0) }
///             .id(shelf.name)
///             .header(Text(shelf.name).fontAttributes(.bold))
///     })
///
/// Each group names itself with `.id`, so two groups may hold equal items; a
/// group given none is named by its place.
public struct ItemsGroup<Items: RandomAccessCollection, ID: Hashable> {
    /// The items.
    let items: Items

    /// How an item names itself.
    let identify: (Items.Element) -> ID

    /// How an item looks.
    let content: (Items.Element) -> any View

    /// What the group names itself, where it was given a name.
    private(set) var name: String?

    /// Its header, where it has one.
    private(set) var header: (any View)?

    /// Its footer, where it has one.
    private(set) var footer: (any View)?

    /// A group of `items`, each its own identity, each looking as `content` says.
    public init<Content: View>(_ items: Items, @ViewBuilder content: @escaping (Items.Element) -> Content)
    where Items.Element: Hashable, ID == Items.Element {
        self.items = items
        identify = { $0 }
        self.content = { content($0) }
    }

    /// A group of `items`, each named by the property `id`, each looking as
    /// `content` says.
    public init<Content: View>(
        _ items: Items, id: KeyPath<Items.Element, ID>, @ViewBuilder content: @escaping (Items.Element) -> Content
    ) {
        self.items = items
        identify = { $0[keyPath: id] }
        self.content = { content($0) }
    }

    /// The group's name, which sets its items apart from another group's.
    public func id(_ value: some Hashable) -> Self {
        var copy = self
        copy.name = String(describing: value)
        return copy
    }

    /// A view standing before the group's items.
    public func header(_ view: any View) -> Self {
        var copy = self
        copy.header = view
        return copy
    }

    /// A view standing after the group's items.
    public func footer(_ view: any View) -> Self {
        var copy = self
        copy.footer = view
        return copy
    }
}
