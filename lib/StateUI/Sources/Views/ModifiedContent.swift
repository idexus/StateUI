// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A composed view with a modifier written on it. It offers what every view
/// has - margin, opacity, where it sits in a grid - and nothing that only
/// some views do.
public struct ModifiedContent: View {
    /// The content's node, with the change written into it.
    public var node: Node

    /// Wraps a node that a modifier has already been applied to. Made by
    /// `ContentView.modified`; there is rarely a reason to call this directly.
    public init(node: Node) {
        self.node = node
    }
}
