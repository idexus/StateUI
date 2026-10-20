// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Where a builder's statement stood, in front of the paths of what it produced.
// Design: docs/design/views/builders.md#every-statement-records-where-it-stood
@MainActor
enum BuilderPath {
    /// The step of an `if`'s branch, of an `else`'s, and of an `if` with no `else`.
    static let first = PathNumber().appending("if")
    static let second = PathNumber().appending("else")
    static let some = PathNumber().appending("some")

    /// The step of a builder's statement `index`.
    static func statement(_ index: Int) -> PathNumber {
        PathNumber().appending(UInt64(index))
    }

    static func tagged(_ segment: PathNumber, _ nodes: [Node]) -> [Node] {
        // Several are numbered under it, so they do not share one path.
        // Design: docs/design/views/builders.md#several-views-from-one-statement
        guard nodes.count > 1 else { return nodes.map { tagged(segment, $0) } }

        return nodes.enumerated().map { tagged(segment.appending(UInt64($0.offset)), $0.element) }
    }

    static func tagged(_ segment: PathNumber, _ node: Node) -> Node {
        var node = node
        node.key = node.key.map { $0.under(segment) } ?? segment
        return node
    }
}
