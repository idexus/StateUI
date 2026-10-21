// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A modifier written on a view that keeps no node of its own - a composed
/// view, or an `if`/`else` of views. It offers what every view has - margin,
/// opacity, where it sits in a grid - and nothing that only some views do;
/// `Content` is the view it was written on.
public struct ModifiedContent<Content: View>: ElementView {
    /// The content's node, with the change written into it.
    public var node: Node

    /// Wraps a node a modifier has been written into.
    init(node: Node) {
        self.node = node
    }
}
