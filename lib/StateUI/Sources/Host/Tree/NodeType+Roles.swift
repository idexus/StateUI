// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What part an element plays in what a host shows, the same on every host.
/// Design: docs/design/host/tree.md#the-native-half
@_spi(Host) extension NodeType {
    /// The arrangements of pages a window shows: a page, a stack of them, tabs, a split view.
    public static let pageTypes: Set<NodeType> = [.page, .navigationStack, .tabbedView, .splitView]

    /// The entries that have no view of their own: structure, and the parts of another's view.
    public static let viewlessTypes: Set<NodeType> = [
        .application, .scene, .window, .modalStack, .titleBar, .content, .leadingContent, .trailingContent,
        .titleView, .toolbarItems, .toolbarItem, .menuBar, .contextMenu, .menu, .menuItem, .menuSeparator, .spans,
        .span,
    ]

    /// A page's children that furnish its chrome rather than stand in its room.
    public static let slotTypes: Set<NodeType> = [.toolbarItems, .titleView, .menuBar, .contextMenu]
}
