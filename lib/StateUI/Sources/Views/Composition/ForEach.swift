// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One view per item of a collection, each keyed by its item - never by the
/// position it happened to be built at.
///
///     VStack {
///         ForEach(names) { name in
///             Label(name)
///         }
///     }
///
/// A collection that gains, loses or reorders items moves the views that
/// stayed - text, caret, focus and `@State` riding along - rather than
/// rewriting what every position shows. A view's own `.id()` wins. Items must
/// be distinct within their parent; where they repeat, name the distinct part
/// with `id:`.
///
/// A plain `for` does not compile inside a view builder, so this is where
/// repetition is written.
public struct ForEach {
    /// The views, one per item, each wearing its item's identity.
    let elements: [Element]

    /// One view per item, the item its identity.
    ///
    ///     ForEach(0..<5) { turn in
    ///         Label("Turn \(turn)")
    ///     }
    ///
    /// A range works: its numbers are the items.
    public init<Items: RandomAccessCollection>(
        _ items: Items,
        content: (Items.Element) -> Element
    ) where Items.Element: Hashable {
        self.init(items, id: \.self, content: content)
    }

    /// One view per item, identified by the part of it `id` names.
    ///
    ///     ForEach(files, id: \.path) { file in
    ///         Label(file.name)
    ///     }
    ///
    /// For items that are not `Hashable` whole, or that repeat - an enumerated
    /// sequence's offsets being the usual case:
    /// `ForEach(Array(titles.enumerated()), id: \.offset)`.
    ///
    /// An identity is compared as text, `String(describing:)`: a `description`
    /// that says less than the value gives two items one identity.
    ///
    /// - Parameter id: which part of an item is its identity - distinct
    ///   across the items, stable while the item means the same row.
    public init<Items: RandomAccessCollection, Id: Hashable>(
        _ items: Items,
        id: KeyPath<Items.Element, Id>,
        content: (Items.Element) -> Element
    ) {
        elements = items.map { item in
            Identified(identity: String(describing: item[keyPath: id]), element: content(item))
        }
    }
}

/// One turn's view, wearing its item's identity unless the author wrote an
/// `.id()` of their own.
/// Design: docs/design/views/builders.md#the-path-rides-a-wrapper
struct Identified: Element {
    /// The item's identity, rendered to the id namespace authors write in.
    let identity: String

    /// The view as the author wrote it, modifiers and all.
    let element: Element

    /// The element's own node, identified.
    var body: Node {
        var node = element.body

        if node.id == nil {
            node.id = identity
        }

        return node
    }
}
