// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if MAUI

/// One group of an `ItemsView`: its items, and what stands before and after
/// them.
///
///     ItemsGroup(shelf.items) { item in
///         Label(item)
///     }
///     .id(shelf.name)
///     .header(Label(shelf.name))
///     .footer(Label("\(shelf.items.count) items"))
///
/// Not a view but data the list lays out. Its header and footer are slots in
/// the run, each kind measured once for the whole list, so every group's
/// header has one length and so does every footer.
public struct ItemsGroup<Items: RandomAccessCollection, Id: Hashable> {
    /// What this group shows, one item each.
    let items: Items

    /// Which part of an element is its identity.
    let path: KeyPath<Items.Element, Id>

    /// The item template.
    let template: (Items.Element) -> Element

    /// Who this group is among its siblings, where the author said.
    var name: String?

    /// What stands before the items.
    var head: (any View)?

    /// And after them.
    var foot: (any View)?

    /// One item per element, the element its identity - the list's own
    /// initializer, one level down.
    ///
    /// - Parameters:
    ///   - items: What this group shows.
    ///   - content: The item template, run for the items in view.
    public init(
        _ items: Items,
        content: @escaping (Items.Element) -> Element
    ) where Items.Element: Hashable, Id == Items.Element {
        self.init(items, id: \.self, content: content)
    }

    /// The same, for elements identified by the part `id` names.
    ///
    /// - Parameters:
    ///   - items: What this group shows.
    ///   - id: Which part of an element is its identity.
    ///   - content: The item template, run for the items in view.
    public init(
        _ items: Items,
        id: KeyPath<Items.Element, Id>,
        content: @escaping (Items.Element) -> Element
    ) {
        self.items = items
        self.path = id
        self.template = content
    }

    /// Who this group is among its siblings - what its items' identities are
    /// written under, so two groups may hold equal items and keep their own.
    /// A group that says nothing is identified by where it sits.
    ///
    /// - Parameter value: The group's identity.
    /// - Returns: The group, under that name.
    public func id(_ value: some Hashable) -> Self {
        var copy = self
        copy.name = String(describing: value)
        return copy
    }

    /// What is drawn before the group's items, scrolling with them.
    ///
    /// - Parameter view: What stands before the items.
    /// - Returns: The group, headed by that view.
    public func header(_ view: any View) -> Self {
        var copy = self
        copy.head = view
        return copy
    }

    /// What is drawn after the group's items, scrolling with them.
    ///
    /// - Parameter view: What stands after the items.
    /// - Returns: The group, followed by that view.
    public func footer(_ view: any View) -> Self {
        var copy = self
        copy.foot = view
        return copy
    }

    /// The element at an offset - the one place a collection that is not an
    /// Array is indexed.
    func item(at offset: Int) -> Items.Element {
        items[items.index(items.startIndex, offsetBy: offset)]
    }
}

#endif
