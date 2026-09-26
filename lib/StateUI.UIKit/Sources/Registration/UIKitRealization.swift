// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What UIKit realizes of the library's elements, as the core and the control dictionary are told it.
enum UIKitRealization {
    /// The entries this host realizes none of yet: it shows each one's name in red where it belongs.
    static let unrealized: Set<String> = [
        "ActivityIndicator", "Canvas", "CheckBox", "ColorBox", "Content", "ContextMenu", "DatePicker", "Ellipse",
        "Grid", "LeadingContent", "Line", "Map", "Menu", "MenuBar", "MenuItem", "MenuSeparator", "ModalStack",
        "NavigationStack", "Overlay", "Path", "Picker", "Pin", "Polygon", "Polyline", "PositionIndicator",
        "ProgressBar", "RadioButton", "Rectangle", "ScrollView", "SearchField", "Slider", "Span", "Spans",
        "SplitView", "Stepper", "Switch", "TabbedView", "TextEditor", "TimePicker", "TitleBar", "TitleView",
        "ToolbarItem", "ToolbarItems", "TrailingContent", "WebView", "ZStack",
    ]
}
#endif
