// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One section of an `ItemsView`'s items, under a header and over a footer where
/// it has them.
///
///     ItemsView(sections: shelves.map { shelf in
///         Section(shelf.items) { Text($0) }
///             .id(shelf.name)
///             .header { Text(shelf.name).fontWeight(.bold) }
///     })
///
/// A section is known by the value `.id` gives it, as an item is by its own;
/// one given none, by its place. An item's value stands once in the whole
/// list, whatever section holds it.
public struct Section<ID: Hashable> {
    /// How many items it holds.
    let count: Int

    /// The identity of the item at a place.
    let identify: (Int) -> ID

    /// The view of the item at a place.
    let content: (Int) -> any View

    /// What the section is known by, where `.id` gave it one.
    private(set) var identity: AnyHashable?

    /// Its header, where it has one.
    private(set) var header: (any View)?

    /// Its footer, where it has one.
    private(set) var footer: (any View)?

    /// A section of `items`, each its own identity, each looking as `content` says.
    public init<Items: RandomAccessCollection, Content: View>(
        _ items: Items, @ViewBuilder content: @escaping (Items.Element) -> Content
    ) where Items.Element == ID {
        self.init(items, identify: { $0 }, content: content)
    }

    /// A section of `items`, each named by the property `id`, each looking as
    /// `content` says.
    public init<Items: RandomAccessCollection, Content: View>(
        _ items: Items, id: KeyPath<Items.Element, ID>, @ViewBuilder content: @escaping (Items.Element) -> Content
    ) {
        self.init(items, identify: { $0[keyPath: id] }, content: content)
    }

    /// The section of `items`, reached by their places.
    private init<Items: RandomAccessCollection, Content: View>(
        _ items: Items, identify: @escaping (Items.Element) -> ID, content: @escaping (Items.Element) -> Content
    ) {
        let item = { (place: Int) in items[items.index(items.startIndex, offsetBy: place)] }
        count = items.count
        self.identify = { identify(item($0)) }
        self.content = { content(item($0)) }
    }

    /// What the section is known by: as the sections change, the one of this id is
    /// the same section, wherever it stands.
    public func id(_ value: some Hashable) -> Self {
        var copy = self
        copy.identity = AnyHashable(value)
        return copy
    }

    /// A view standing before the section's items.
    public func header<Content: View>(@ViewBuilder _ content: () -> Content) -> Self {
        var copy = self
        copy.header = content()
        return copy
    }

    /// A view standing after the section's items.
    public func footer<Content: View>(@ViewBuilder _ content: () -> Content) -> Self {
        var copy = self
        copy.footer = content()
        return copy
    }
}
