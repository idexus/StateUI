// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

extension View where Modified == ModifiedContent {
    // Design: docs/design/views/composition.md#a-composed-view-is-a-placeholder
    /// A placeholder for the body, which the differ builds once it knows
    /// whether this view stood here last render - so its `@State` is kept.
    /// Assigning to it does nothing.
    public var node: Node {
        get { Node.composed(self, type: String(reflecting: Self.self), shown: Self.self) { body.node } }
        set {}
    }

    /// A modifier written on a composed view, kept on a `ModifiedContent`
    /// wrapping the placeholder.
    public func modified(_ change: (inout Node) -> Void) -> ModifiedContent {
        var node = self.node
        change(&node)
        return ModifiedContent(node: node)
    }
}
