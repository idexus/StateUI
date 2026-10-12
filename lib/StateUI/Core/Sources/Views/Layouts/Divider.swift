// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A line across a stack, grouping the views before it apart from the ones after.
///
///     VStack {
///         Text("Inbox")
///         Divider()
///         Text("Archive")
///     }
///
/// The line runs across the stack's axis, as thick as the platform draws one. A line between a menu's entries
/// is a `MenuSeparator`.
///
/// Design: docs/design/host/layout.md#a-divider-in-a-stack
public struct Divider: ElementView {
    /// The node this separator describes.
    public var node: Node

    /// A line.
    public init() {
        node = Node(contract: DividerContract.self)
    }
}
