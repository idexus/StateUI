// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What part an element plays in what a host shows, the same on every host.
/// Design: docs/design/host/tree.md#the-native-half
@_spi(Host) extension NodeType {
    /// The arrangements of pages a window shows: a page, a stack of them, tabs, a split view, a page with sheets over
    /// it.
    public static let pageTypes: Set<NodeType> = [.page, .navigationStack, .tabView, .splitView, .modalStack]

    /// The entries that have no view of their own: structure, and the parts of another's view.
    public static let viewlessTypes: Set<NodeType> = [
        .application, .scene, .window, .modalStack, .titleView, .toolbarItemGroup, .toolbarItem, .menuBar, .contextMenu,
        .menu, .menuItem, .textSpans, .textSpan,
    ]

    /// The entries a menu draws itself.
    public static let menuTypes: Set<NodeType> = [.menuBar, .contextMenu, .menu, .menuItem]

    /// Whether an entry of `type` standing under `parent` has no view of its own: a divider is a menu's separator
    /// in a menu and a view in a stack.
    public static func isViewless(_ type: NodeType, under parent: NodeType?) -> Bool {
        if type == .divider { return parent.map { menuTypes.contains($0) } ?? true }
        return viewlessTypes.contains(type)
    }

    /// What is declared on an element to furnish the chrome or the window rather than stand in its room.
    public static let slotTypes: Set<NodeType> = [.toolbarItemGroup, .titleView, .menuBar, .contextMenu, .overlay]
}

@_spi(Host) extension MountedElement {
    /// Whether this element has no view of its own, where it stands (`NodeType.isViewless(_:under:)`).
    public var isViewless: Bool {
        NodeType.isViewless(type, under: parent?.type)
    }
}
