// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The result builder behind the nested syntax. Besides joining statements into
// a child list, every method records where each view was written - a path such
// as "1.else.0" that `Node.key` carries to the differ as the view's key.
// Design: docs/design/views/builders.md#every-statement-records-where-it-stood

/// Collects child views written as consecutive statements into an array.
/// Every closure in this library that takes views is one of these.
///
/// `if`, `if/else`, `switch`, `ForEach` and `if #available` work inside one.
/// A plain `for` does not compile: repeat views with `ForEach`, which keys
/// each view by its item.
///
///     VStack {
///         Label("Files")
///
///         ForEach(files, id: \.path) { file in
///             Label(file.name)
///         }
///     }
@resultBuilder
public enum ViewBuilder {
    /// A single view written as a statement.
    public static func buildExpression(_ expression: Element) -> [Element] {
        [expression]
    }

    /// Several, from something that already produced a list.
    public static func buildExpression(_ expression: [Element]) -> [Element] {
        expression
    }

    /// The statements of the closure, in the order they are written, each
    /// keyed by its statement's number whatever the others produce.
    public static func buildBlock(_ components: [Element]...) -> [Element] {
        components.enumerated().flatMap { at($0.offset, $0.element) }
    }

    /// An `if` without an `else`; what it builds is keyed apart from the
    /// statement after it.
    public static func buildOptional(_ component: [Element]?) -> [Element] {
        component.map { tag("some", $0) } ?? []
    }

    /// The `if` branch of an if/else.
    public static func buildEither(first component: [Element]) -> [Element] {
        tag("if", component)
    }

    /// The `else` branch. Its views are keyed apart from the `if` branch's, so
    /// switching branches replaces the control rather than editing it.
    public static func buildEither(second component: [Element]) -> [Element] {
        tag("else", component)
    }

    /// A `ForEach`'s views, each keyed by its item.
    public static func buildExpression(_ expression: ForEach) -> [Element] {
        expression.elements
    }

    /// What an `if #available(…)` block builds, keyed like every other branch.
    public static func buildLimitedAvailability(_ component: [Element]) -> [Element] {
        tag("available", component)
    }

    /// Puts one segment in front of everything a statement produced, numbering
    /// several views under it.
    /// Design: docs/design/views/builders.md#several-views-from-one-statement
    private static func tag(_ segment: String, _ elements: [Element]) -> [Element] {
        guard elements.count > 1 else {
            return elements.map { Keyed(segment: segment, element: $0) }
        }

        return elements.enumerated().map {
            Keyed(segment: "\(segment).\($0.offset)", element: $0.element)
        }
    }

    private static func at(_ index: Int, _ elements: [Element]) -> [Element] {
        tag(String(index), elements)
    }
}

/// One more segment on an element's path, added without touching the element.
/// Design: docs/design/views/builders.md#the-path-rides-a-wrapper
struct Keyed: Element {
    /// What to put in front of whatever path the element already has.
    let segment: String

    /// The element as the author wrote it, modifiers and all.
    let element: Element

    /// The element's own node, with the segment on the front of its path.
    var body: Node {
        var node = element.body
        node.key = node.key.map { "\(segment).\($0)" } ?? segment
        return node
    }
}
