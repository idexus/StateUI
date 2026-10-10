// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A line between entries, grouping the ones above it apart from the ones
/// below.
///
///     Menu("File") {
///         MenuItem("New").onClicked { create() }
///         Divider()
///         MenuItem("Close").onClicked { close() }
///     }
///
/// It has no caption and nothing to click; the platform draws whatever a
/// separator looks like there.
public struct Divider: Element {
    /// The node this separator describes.
    public var node: Node

    /// A line.
    public init() {
        node = Node(contract: DividerContract.self)
    }

    /// Who this separator is, among the menu's others - worth giving one when
    /// entries come and go around it.
    public func id(_ value: some Hashable) -> Self {
        var copy = self
        copy.node.identify(value)
        return copy
    }
}
