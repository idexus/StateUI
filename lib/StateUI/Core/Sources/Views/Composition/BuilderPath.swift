// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Where a builder's statement stood, in front of the paths of what it produced.
// Design: docs/design/views/builders.md#every-statement-records-where-it-stood
enum BuilderPath {
    static func tagged(_ segment: String, _ nodes: [Node]) -> [Node] {
        // Several are numbered under it, so they do not share one path.
        // Design: docs/design/views/builders.md#several-views-from-one-statement
        guard nodes.count > 1 else { return nodes.map { tagged(segment, $0) } }

        return nodes.enumerated().map { tagged("\(segment).\($0.offset)", $0.element) }
    }

    static func tagged(_ segment: String, _ node: Node) -> Node {
        var node = node
        node.key = node.key.map { "\(segment).\($0)" } ?? segment
        return node
    }
}
