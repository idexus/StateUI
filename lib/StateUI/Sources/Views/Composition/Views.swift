// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a container holds: none, one or several views in order, each keyed by
/// where it was written. Every view is one; the view builder makes the rest -
/// `Statements` for several statements, `Either` for the branches of an `if`,
/// an optional for an `if` with no `else`, `ForEach` for repetition.
public protocol Views {
    /// The nodes, in order, each carrying where it was written.
    var nodes: [Node] { get }
}

extension View {
    /// The view alone.
    public var nodes: [Node] { [body] }
}

/// Views held as `any View`, in order, matched by their places.
extension Array: Views where Element == any View {
    /// The views' nodes, in order.
    public var nodes: [Node] { map(\.body) }
}

/// What an `if` with no `else` built: nothing, or what its branch built, keyed
/// apart from the statement after it.
extension Optional: Views where Wrapped: Views {
    /// The branch's nodes, or none.
    public var nodes: [Node] {
        map { BuilderPath.tagged("some", $0.nodes) } ?? []
    }
}
