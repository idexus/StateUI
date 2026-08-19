// The identified loop - the one way to repeat views.

/// One view per item of a collection, each identified by its ITEM - never by
/// the position it happened to be built at.
///
///     VStack {
///         ForEach(names) { name in
///             Label(name)
///         }
///     }
///
/// The name and the rule are SwiftUI's `ForEach`: the item is the row's
/// identity, so a collection that gains, loses or reorders items moves the
/// views that stayed rather than rewriting what every position shows - text,
/// caret, focus and `@State` riding along. A view may still write its own
/// `.id()` and the author's wins. Items must be DISTINCT within their parent,
/// since equal items are one identity twice - SwiftUI's rule again; when the
/// items themselves repeat, name the distinct part with `id:`.
///
/// A plain `for` deliberately does not compile inside a view builder -
/// `ViewBuilder` and `MenuBuilder` have no `buildArray` - so this is where
/// repetition is written. A loop turn has no identity but its number, which IS
/// the position: gain a row at the top and every turn below it renumbers, and
/// the views are rebuilt as though each of them had changed.
public struct ForEach {
    /// The views, one per item, each wearing its item's identity.
    let elements: [Element]

    /// One view per item, the item its identity.
    ///
    ///     ForEach(0..<5) { turn in
    ///         Label("Turn \(turn)")
    ///     }
    ///
    /// A range works because its numbers are the items - which is also the
    /// honest spelling of a static loop.
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
    /// For items that are not `Hashable` whole - or repeat, an enumerated
    /// sequence's offsets being the classic case:
    /// `ForEach(Array(titles.enumerated()), id: \.offset)`.
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

/// One turn's view, wearing its item's identity - unless the author wrote an
/// `.id()` of their own, which wins.
///
/// A wrapper rather than a property on the controls, for `Keyed`'s reason: the
/// builder is handed an `Element` and must not care which one, so the identity
/// lands on whatever node the element builds - a composed view's placeholder
/// included, which is where an identity has to sit for the differ to see it.
/// Nothing is built any earlier than it would be without one.
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
