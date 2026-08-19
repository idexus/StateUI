// Not building what cannot have changed.
//
// A render runs the author's closures in full, top to bottom, and the differ
// walks the result to find the handful of things that moved. That is correct,
// and for a list of a thousand rows it is a thousand subtrees built and compared
// so that one of them can be sent.
//
// A view that knows what it depends on can say so:
//
//     Row(item: item)
//         .memoized(by: item)
//         .id(item.id)
//
// and while `item` is equal to what it was, the row is not built, not compared
// and not sent. The differ keeps the subtree it already had.
//
// THE PROMISE IT ASKS FOR - "everything this view shows comes from these
// inputs" - is the one React's memo and SwiftUI's EquatableView ask for, and it
// breaks the same way: by copying state into the view during a render and
// expecting the copy to keep up. `memoized(by:)` says which reads are safe and
// which are not.
//
// The differ does the same reasoning by itself for everything else, from what a
// build READS - see Core/Invalidation.swift. This is the form an author reaches
// for where the inputs can be DECLARED and the subtree is expensive enough to
// be worth not walking at all.

/// A view that is skipped while its inputs are unchanged.
///
/// Made by `Element.memoized(by:)`; there is no reason to write one directly.
public struct Memoized: Element {
    let token: AnyHashable
    var identity: String?
    let build: () -> Node

    /// A placeholder carrying the token and the closure - NOT the subtree. The
    /// differ calls the closure only when the token has moved, which is where
    /// the work is skipped.
    public var body: Node {
        var node = Node(type: .memoized, id: identity)
        node.memo = Node.Memo(token: token, build: build)
        return node
    }

    /// Who this view is among its siblings, as everywhere else.
    ///
    ///     Row(item: item)
    ///         .memoized(by: item)
    ///         .id(item.id)
    ///
    /// It belongs HERE rather than on the view inside: identity is decided
    /// before anything is built, and the view inside may not be built at all.
    ///
    /// - Parameter value: who this view is - any `Hashable`, described into
    ///   text the way every other identity in this library is.
    public func id(_ value: some Hashable) -> Self {
        var copy = self
        copy.identity = String(describing: value)
        return copy
    }
}

extension Element {
    /// Skips this view, and everything under it, while `value` is unchanged.
    ///
    ///     Row(item: item)
    ///         .memoized(by: item)
    ///         .id(item.id)
    ///
    /// Worth it where a subtree is expensive and its inputs are narrow - the
    /// rows of a long list, above all. Not worth it on a Label: comparing the
    /// token costs about what building the Label would.
    ///
    /// **The promise is that everything this view shows comes from `value`.**
    /// Reading state inside a memoized view is fine - a `State` is a reference,
    /// so a handler that reads one when it fires sees the current value, and a
    /// body's reads are recorded and rebuilt. What breaks the promise is
    /// COPYING state into the view during the render and expecting the copy to
    /// keep up:
    ///
    ///     let total = basket.get().count          // read during the render
    ///     Label("\(total)").memoized(by: item)    // wrong: total is not an input
    ///
    /// Write it LAST in a chain: what it gives back is a promise to build a
    /// view rather than a view.
    ///
    /// - Parameter value: everything the view depends on, as one `Hashable`.
    public func memoized<Value: Hashable>(by value: Value) -> Memoized {
        // `self` is captured, not read: `body` runs inside the closure, which
        // the differ calls only when the token has changed. That is where the
        // work is skipped.
        Memoized(token: AnyHashable(value)) { self.body }
    }
}
