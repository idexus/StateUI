// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What this host realizes beyond its registry, whose export says the rest - the UIKit column of the control
/// dictionary; a member is recorded once a test of this package covers it.
/// Design: docs/design/contracts/dictionary.md#marks
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

    /// Every record: none yet, so the registry's export says all this host realizes.
    static let records: [HostRecord] = []

    /// What UIKit's registry says it realizes: the export's content.
    @MainActor static var declaration: HostDeclaration {
        let registry = UIKitRegistrations.registry
        return HostDeclaration(realization: registry.realization, shared: registry.sharedNames, acts: [])
    }

    /// What UIKit realizes, member by member: these records before what its registry says.
    @MainActor static var register: HostRegister {
        HostRegister(records: records, unrealized: unrealized, viewless: [], notPlanned: [:]).and(declaration)
    }
}
#endif
