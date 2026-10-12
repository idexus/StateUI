// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A line between entries, grouping the ones before it apart from the ones after - in a menu, or across a stack.
///
///     Menu("File") {
///         MenuItem("New").onClicked { create() }
///         Divider()
///         MenuItem("Close").onClicked { close() }
///     }
///
///     VStack {
///         Text("Inbox")
///         Divider()
///         Text("Archive")
///     }
///
/// It has no caption and nothing to click; the platform draws its own separator. In a stack the line runs
/// across the stack's axis, as thick as the platform draws one.
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
