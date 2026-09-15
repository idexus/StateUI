// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Every contract the library declares, the tiers first - what the guards
/// holding the contracts read, and what the tables derived from them are
/// built out of.
enum LibraryContracts {
    /// The tiers, in the dictionary's order.
    static let tiers: [any Contract.Type] = [
        PropertyContainerContract.self,
        VisualElementContract.self,
        ViewContract.self,
        LayoutContract.self,
        StackBaseContract.self,
        InputViewContract.self,
        ShapeContract.self,
        TextElementContract.self,
        TextStyleElementContract.self,
        FontElementContract.self,
        TextAlignmentElementContract.self,
        LineHeightElementContract.self,
        DecorableTextElementContract.self,
        PaddingElementContract.self,
        BorderElementContract.self,
        ImageElementContract.self,
        TintElementContract.self,
        BarElementContract.self,
        MenuItemElementContract.self,
        PageElementContract.self,
    ]

    /// Every element: one contract per node type the library declares.
    static let elements: [any ElementContract.Type] = [
        AbsoluteLayoutContract.self, ActivityIndicatorContract.self, ApplicationContract.self,
        BorderContract.self, ButtonContract.self, CanvasContract.self, CheckBoxContract.self,
        ColorBoxContract.self, ContentContract.self, ContextMenuContract.self, DatePickerContract.self,
        EllipseContract.self, GridContract.self, HStackContract.self, ImageContract.self, LabelContract.self,
        LeadingContentContract.self, LineContract.self, MapContract.self, MenuBarContract.self,
        MenuContract.self, MenuItemContract.self, MenuSeparatorContract.self, ModalStackContract.self,
        NavigationStackContract.self, OverlayContract.self, PageContract.self, PathContract.self,
        PickerContract.self, PinContract.self, PolygonContract.self, PolylineContract.self,
        PositionIndicatorContract.self, ProgressBarContract.self, RadioButtonContract.self,
        RectangleContract.self, RefreshViewContract.self, SceneContract.self, ScrollViewContract.self,
        SearchFieldContract.self, SettersContract.self, SliderContract.self, SpanContract.self,
        SpansContract.self, SplitViewContract.self, StepperContract.self, SwipeActionContract.self,
        SwipeActionsContract.self, SwipeViewContract.self, SwitchContract.self, TabbedViewContract.self,
        TextEditorContract.self, TextFieldContract.self, TimePickerContract.self, TitleBarContract.self,
        TitleViewContract.self, ToolbarItemContract.self, ToolbarItemsContract.self,
        TrailingContentContract.self, VStackContract.self, VisualStateContract.self, WebViewContract.self,
        WindowContract.self,
    ]

    /// Every contract.
    static let all: [any Contract.Type] = tiers + elements.map { $0 as any Contract.Type }

    /// Every property's facts, by the name it crosses under - what the differ
    /// asks of a property it holds only a token for. The members of one name
    /// say the same (`LibraryContractTests`), so the first one met answers for
    /// them all.
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

extension Prop {
    /// What the members of this name say: whether a change travels, whether a
    /// lost value is cleared, which of a view's values it is. A name no library
    /// contract declares - an application's own - travels, is cleared, and
    /// says nothing of motion.
    var facts: MemberFacts {
        LibraryContracts.facts[self] ?? .undeclared
    }
}
