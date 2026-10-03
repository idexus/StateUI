// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// An arrangement is a view that stands where a page stands, told by the type of the view written there.
// Design: docs/design/views/pages.md#an-arrangement-is-a-view

/// A view arranging pages: `NavigationStack`, `TabView`, `SplitView`, `ModalStack`.
protocol Arrangement: ElementView {}

extension NodeType {
    /// The arrangements' node types.
    static let arrangements: Set<NodeType> = [
        NavigationStackContract.nodeType, TabViewContract.nodeType, SplitViewContract.nodeType,
        ModalStackContract.nodeType,
    ]

    /// Where a page stands: in a window, and among an arrangement's pages.
    static let pagePositions: Set<NodeType> = arrangements.union([WindowContract.nodeType])
}

extension Node {
    /// Whether a view of this type builds an arrangement at its root; nil where its body chooses at run time, or
    /// holds a view of any type.
    static func isArrangement<Shown: View>(_ shown: Shown.Type) -> Bool? {
        if shown is any Arrangement.Type { return true }
        if let branches = shown as? any Branches.Type { return branches.isArrangement }
        if shown is ModifiedContent.Type { return nil }
        if Shown.Body.self is Never.Type { return false }

        return isArrangement(Shown.Body.self)
    }

    /// Whether this node builds an arrangement: told by its type, or by the type of the view it is a placeholder
    /// for; nil where that type cannot tell.
    var isArrangement: Bool? {
        guard let stateful else { return NodeType.arrangements.contains(type) }

        return stateful.shown.flatMap { Node.isArrangement($0) }
    }
}

/// An `if`/`else` of views, telling whether both of its branches build an arrangement.
private protocol Branches {
    static var isArrangement: Bool? { get }
}

extension Either: Branches where First: View, Second: View {
    static var isArrangement: Bool? {
        let first = Node.isArrangement(First.self)
        return first == Node.isArrangement(Second.self) ? first : nil
    }
}
