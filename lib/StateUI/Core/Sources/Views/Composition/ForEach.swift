// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One view per item of a collection, each keyed by its item - never by the
/// position it happened to be built at.
///
///     VStack {
///         ForEach(names) { name in
///             Text(name)
///         }
///     }
///
/// A collection that gains, loses or reorders items moves the views that
/// stayed - text, caret, focus and `@State` riding along - rather than
/// rewriting what every position shows. A view's own `.id()` wins. Items must
/// be distinct within their parent; where they repeat, name the distinct part
/// with `id:`. A row is one view: an `if`/`else` works in it.
///
/// A plain `for` does not compile inside a view builder, so this is where
/// repetition is written.
public struct ForEach: Views {
    /// The views' nodes, one per item, each wearing its item's identity.
    public let nodes: [Node]

    /// One view per item, the item its identity.
    ///
    ///     ForEach(0..<5) { turn in
    ///         Text("Turn \(turn)")
    ///     }
    ///
    /// A range works: its numbers are the items.
    public init<Items: RandomAccessCollection, Content: View>(
        _ items: Items,
        @ViewBuilder content: (Items.Element) -> Content
    ) where Items.Element: Hashable {
        self.init(items, id: \.self, content: content)
    }

    /// One view per item, identified by the part of it `id` names.
    ///
    ///     ForEach(files, id: \.path) { file in
    ///         Text(file.name)
    ///     }
    ///
    /// For items that are not `Hashable` whole, or that repeat - an enumerated
    /// sequence's offsets being the usual case:
    /// `ForEach(Array(titles.enumerated()), id: \.offset)`.
    ///
    /// An identity is named in the patch by `String(describing:)`: two items
    /// with one identity, or two that describe themselves alike, are said.
    ///
    /// - Parameter id: which part of an item is its identity - distinct
    ///   across the items, stable while the item means the same row.
    public init<Items: RandomAccessCollection, ID: Hashable, Content: View>(
        _ items: Items,
        id: KeyPath<Items.Element, ID>,
        @ViewBuilder content: (Items.Element) -> Content
    ) {
        // The item's identity, unless the author wrote an `.id()` of their own.
        // Design: docs/design/views/builders.md#foreach-keys-are-text
        nodes = items.map { item in
            var node = content(item).node
            if node.id == nil { node.identify(item[keyPath: id]) }
            return node
        }
    }
}
