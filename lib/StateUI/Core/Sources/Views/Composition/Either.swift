// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One branch of an `if`/`else` or a `switch`, keyed by which: switching
/// branches replaces what stood there rather than editing it. A view where
/// both branches are views - so an `if`/`else` is content of its own.
public enum Either<First, Second> {
    /// The `if` branch.
    case first(First)

    /// The `else` branch.
    case second(Second)
}

extension Either: Views where First: Views, Second: Views {
    /// The branch's nodes under which branch it is.
    public var nodes: [Node] {
        switch self {
        case .first(let first): BuilderPath.tagged("if", first.nodes)
        case .second(let second): BuilderPath.tagged("else", second.nodes)
        }
    }
}

extension Either: Element where First: Element, Second: Element {
    /// The branch's node under which branch it is, read afresh each time;
    /// assigning to it does nothing.
    public var node: Node {
        get {
            switch self {
            case .first(let first): BuilderPath.tagged("if", first.node)
            case .second(let second): BuilderPath.tagged("else", second.node)
            }
        }
        set {}
    }
}

extension Either: PropertyContainer, ModifiableElement, VisualElementProperties, VisualElement, ViewProperties,
    View where First: View, Second: View {
    /// A modifier on a branch is kept on the branch's node, as on a composed view.
    public typealias Modified = ModifiedContent

    /// None: a branch is described by the view it chose.
    public var body: Never { fatalError("a branch has no body: it is the view it chose") }

    /// A modifier written on the branch, kept on a `ModifiedContent`.
    public func modified(_ change: (inout Node) -> Void) -> ModifiedContent {
        var node = self.node
        change(&node)
        return ModifiedContent(node: node)
    }
}
