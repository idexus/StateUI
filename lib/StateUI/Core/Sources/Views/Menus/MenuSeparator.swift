// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A line between a menu's entries, grouping the ones before it apart from the ones after.
///
///     Menu("File") {
///         MenuItem("New").onClicked { create() }
///         MenuSeparator()
///         MenuItem("Close").onClicked { close() }
///     }
///
/// It has no caption, nothing to click and nothing to change: the platform draws its own separator. A line
/// across a stack is a `Divider`.
public struct MenuSeparator: Element {
    /// The node this separator describes.
    public var node: Node

    /// A separator.
    public init() {
        node = Node(contract: MenuSeparatorContract.self)
    }

    /// Who this separator is among the menu's entries, so it stays matched to
    /// itself when the entries around it come and go; without one it is
    /// matched by position.
    public func id(_ value: some Hashable) -> Self {
        var copy = self
        copy.node.identify(value)
        return copy
    }
}
