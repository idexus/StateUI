// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What part an element plays in what a host shows, the same on every host.
/// Design: docs/design/host/tree.md#the-native-half
@_spi(Host) extension NodeType {
    /// The arrangements of pages a window shows: a page, a stack of them, tabs, a split view.
    public static let pageTypes: Set<NodeType> = [.page, .navigationStack, .tabView, .splitView]

    /// The views that take the room they are given rather than asking one: a list, a layout engine, a map, a web
    /// view - a sheet holding one stands at its platform's standard size (`SheetSize`).
    public static let roomTakingTypes: Set<NodeType> = [.itemsView, .layoutEngine, .map, .webView]

    /// The entries that have no view of their own: structure, and the parts of another's view.
    public static let viewlessTypes: Set<NodeType> = [
        .application, .scene, .window, .anchor, .sheet, .titleView, .toolbarItemGroup, .toolbarItem, .menuBar, .contextMenu,
        .menu, .menuItem, .menuSeparator, .buttonMenu, .textSpans, .textSpan,
    ]

    /// The entries a menu draws itself.
    public static let menuTypes: Set<NodeType> = [.menuBar, .contextMenu, .buttonMenu, .menu, .menuItem, .menuSeparator]

    /// What is declared on an element to furnish the chrome or the window rather than stand in its room.
    public static let slotTypes: Set<NodeType> = [
        .toolbarItemGroup, .titleView, .menuBar, .contextMenu, .buttonMenu, .overlay, .popover, .sheet,
    ]

    /// The elements that lay words out in their room - a label, a button: one whose place travels stands at the size
    /// it is bound for, its words there meanwhile (`PlacedView.travels(to:)`).
    /// Design: docs/design/host/motion.md#words-at-their-destination
    public static let wordsTypes: Set<NodeType> = [.text, .button]
}

@_spi(Host) extension MountedElement {
    /// Whether this element has no view of its own (`NodeType.viewlessTypes`).
    public var isViewless: Bool {
        NodeType.viewlessTypes.contains(type)
    }
}
