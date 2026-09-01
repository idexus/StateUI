// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

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
// THE PROMISE IT ASKS FOR is "everything this view shows comes from these
// inputs", and it breaks one way: by copying state into the view during a
// render and expecting the copy to keep up. `memoized(by:)` says which reads
// are safe and which are not.
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

// WHERE `.memoized(by:)` LIVES, and where it deliberately does not.
//
// The word is offered only where there is deferred work for the token to
// prevent: a CONTAINER keeps its content in a closure the differ runs, a
// COMPOSED view keeps its whole body behind a placeholder, and a MODIFIED
// chain wraps one of those. A leaf control has neither - a `Label` is built
// by the line that writes it, so a token on it could save nothing - and
// offering the word there would be a promise the library cannot keep.
extension ContentView {
    /// Skips this view, and everything under it, while `value` is unchanged.
    ///
    ///     Row(item: item)
    ///         .memoized(by: item)
    ///         .id(item.id)
    ///
    /// Worth it where a subtree is expensive and its inputs are narrow - the
    /// rows of a long list, above all.
    ///
    /// **THE TOKEN IS THE WHOLE OF WHAT THIS VIEW DEPENDS ON**, and while it
    /// holds nothing under here is built, compared or sent - state included.
    /// A view that shows state puts that state IN the token:
    ///
    ///     Row(item: item, open: isOpen)
    ///         .memoized(by: [AnyHashable(item), AnyHashable(isOpen)])
    ///
    /// Written the other way round, the state is simply not shown to move:
    ///
    ///     Row(item: item, open: isOpen)
    ///         .memoized(by: item)     // opening it changes nothing on screen
    ///
    /// That is deliberate rather than a trap to be caught. A subtree big
    /// enough to be worth memoizing almost always touches state somewhere, so
    /// a token that yielded to a read would save nothing at all - the word
    /// would mean "compare, then build anyway". A HANDLER is different: it
    /// runs when it fires and reads whatever the state says then, so a button
    /// inside a memoized view works exactly as it looks.
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

/// A view whose content waits in a closure until the differ asks for it -
/// which is what makes `.memoized(by:)` able to save anything: the token is
/// compared before the closure runs.
///
/// Adopted by every control whose initializer takes a `@ViewBuilder`. A leaf
/// control does not qualify - its node is built by the line that writes it -
/// and neither does a hand-written `Node`.
public protocol DeferredContent: Element {}

extension DeferredContent {
    /// Skips this container, and everything under it, while `value` is
    /// unchanged - the content closure is not run, nothing is compared and
    /// nothing is sent.
    ///
    ///     Grid { rows() }.memoized(by: revision)
    ///
    /// **The token is the whole of what the content depends on**, and while
    /// it holds the closure does not run. See `ContentView.memoized(by:)` for
    /// what that means for state read inside.
    ///
    /// - Parameter value: everything the content depends on, as one `Hashable`.
    public func memoized<Value: Hashable>(by value: Value) -> Memoized {
        Memoized(token: AnyHashable(value)) { self.body }
    }
}

extension ModifiedContent {
    /// Skips the modified view, and everything under it, while `value` is
    /// unchanged.
    ///
    /// On the WRAPPER rather than only on the view inside, because a chain of
    /// modifiers is how a container or a composed view is usually finished -
    /// `.memoized` is written last, and last is after the chain.
    ///
    /// - Parameter value: everything the view depends on, as one `Hashable`.
    public func memoized<Value: Hashable>(by value: Value) -> Memoized {
        Memoized(token: AnyHashable(value)) { self.body }
    }
}
