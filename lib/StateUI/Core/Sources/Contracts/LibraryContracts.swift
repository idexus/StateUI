// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Every contract the library declares, the tiers first - what the guards
/// holding the contracts read, and what the tables derived from them are
/// built out of.
/// Design: docs/design/contracts/README.md#the-contracts-of-the-library
@_spi(Host) public enum LibraryContracts {
    /// The tiers, in the dictionary's order.
    public static let tiers: [any Contract.Type] = [
        AutomationElementContract.self,
        VisualElementContract.self,
        ViewContract.self,
        LayoutContract.self,
        StackContract.self,
        TextInputContract.self,
        ShapeContract.self,
        FilledShapeContract.self,
        CorneredShapeContract.self,
        TextualElementContract.self,
        TextColorElementContract.self,
        FontElementContract.self,
        TextAlignmentElementContract.self,
        LineHeightElementContract.self,
        TrackingElementContract.self,
        DecorableTextElementContract.self,
        PaddingElementContract.self,
        BorderElementContract.self,
        ImageElementContract.self,
        TintElementContract.self,
        KeyboardElementContract.self,
        FocusElementContract.self,
        RefreshElementContract.self,
        BarElementContract.self,
        BarItemElementContract.self,
        BarButtonElementContract.self,
        MenuItemElementContract.self,
        ActionElementContract.self,
        ButtonMenuElementContract.self,
        TextAndIconElementContract.self,
        PageElementContract.self,
    ]

    /// Every element: one contract per node type the library declares.
    public static let elements: [any ElementContract.Type] = [
        SpinnerContract.self, AnchorContract.self, ApplicationContract.self, BottomBarContract.self,
        ButtonContract.self, ButtonMenuContract.self, CanvasContract.self, CapsuleContract.self, CheckBoxContract.self,
        ColorPickerContract.self, ContextMenuContract.self, DatePickerContract.self,
        EllipseContract.self, FillContract.self, GridContract.self, HStackContract.self, ImageContract.self,
        ItemsViewContract.self,
        TextContract.self,
        PhaseLayoutContract.self, LineContract.self, LinkContract.self, MapContract.self, MenuBarContract.self,
        MenuContract.self, MenuItemContract.self, MenuToggleContract.self, MenuSeparatorContract.self, SeparatorContract.self,
        NavigationStackContract.self, OverlayContract.self, PageContract.self, PathContract.self,
        PickerContract.self, PopoverContract.self, SheetContract.self, MarkerContract.self, PolygonContract.self, PolylineContract.self,
        ProgressBarContract.self,
        RectangleContract.self, SceneContract.self, ScrollViewContract.self,
        SearchFieldContract.self, SliderContract.self, SpaceContract.self, TextSpanContract.self,
        TextSpansContract.self, SplitViewContract.self, StepperContract.self, SwitchContract.self,
        TabViewContract.self, TextEditorContract.self, TextFieldContract.self, TimePickerContract.self,
        TitleViewContract.self, ToolbarButtonContract.self, ToolbarGroupContract.self, ToolbarToggleContract.self,
        VStackContract.self, WebViewContract.self,
        WindowContract.self, ZStackContract.self,
    ]

    /// Every contract.
    static let all: [any Contract.Type] = tiers + elements.map { $0 as any Contract.Type }

    /// Every property's facts, by the name it crosses under - what the differ
    /// asks of a property it holds only a token for. The first member met
    /// answers for every member of its name.
    /// Design: docs/design/contracts/member-facts.md#one-name-one-set-of-facts
    static let facts: [Prop: MemberFacts] = {
        var facts: [Prop: MemberFacts] = [:]

        for contract in all {
            for case let member as any PropertyMember in contract.members where facts[Prop(member.name)] == nil {
                facts[Prop(member.name)] = member.facts
            }
        }

        return facts
    }()
}

extension LibraryContracts {
    /// The properties another value of which makes the element anew, in their names' order.
    /// Design: docs/design/core/identity-and-diffing.md#another-kind-of-view
    static let remaking: [Prop] = facts.filter { $0.value.remakes }.keys.sorted()
}

extension Prop {
    /// What the members of this name say: whether a change animates, whether a
    /// lost value is cleared, which of a view's values it is. A name no library
    /// contract declares - an application's own - animates, is cleared, and
    /// says nothing of its group.
    var facts: MemberFacts {
        LibraryContracts.facts[self] ?? .undeclared
    }
}
