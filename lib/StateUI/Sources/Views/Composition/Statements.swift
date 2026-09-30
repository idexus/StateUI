// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Several statements of a view builder, in the order they are written, each
/// keyed by its number. What a container holds - never one view, so content
/// written as two statements does not compile.
public struct Statements<each Part: Views>: Views {
    /// The statements, as the builder handed them over.
    let parts: (repeat each Part)

    /// The statements `part`.
    init(_ part: repeat each Part) {
        parts = (repeat each part)
    }

    /// Each statement's nodes under its number.
    public var nodes: [Node] {
        var all: [Node] = []
        var index = 0
        for part in repeat each parts {
            all += BuilderPath.tagged(String(index), part.nodes)
            index += 1
        }
        return all
    }
}
