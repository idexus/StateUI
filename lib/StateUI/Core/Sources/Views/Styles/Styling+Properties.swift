// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What a style may say: the property half of each tier its target wears,
// and its target's own properties.
// Design: docs/design/views/tiers.md#two-halves

extension Styling: VisualElementProperties where Target: VisualElement {}
extension Styling: BarItemElement where Target: BarItemElement {}
extension Styling: PlaceholderElement where Target: PlaceholderElement {}
extension Styling: LineBreakElement where Target: LineBreakElement {}
extension Styling: ViewProperties where Target: View {}
extension Styling: LayoutProperties where Target: Layout {}
extension Styling: StackProperties where Target: Stack {}
extension Styling: HStackProperties where Target == HStack {}
extension Styling: ShapeProperties where Target: Shape {}
extension Styling: FilledShapeProperties where Target: FilledShape {}
extension Styling: CorneredShapeProperties where Target: CorneredShape {}
extension Styling: PaddingElement where Target: PaddingElement {}
extension Styling: TextColorElement where Target: TextColorElement {}
extension Styling: TextualElement where Target: TextualElement {}
extension Styling: FontElement where Target: FontElement {}
extension Styling: TintElement where Target: TintElement {}
extension Styling: TextAlignmentElement where Target: TextAlignmentElement & VisualElement {}
extension Styling: LineHeightElement where Target: LineHeightElement {}
extension Styling: TrackingElement where Target: TrackingElement {}
extension Styling: DecorableTextElement where Target: DecorableTextElement {}
extension Styling: BorderElement where Target: BorderElement {}
extension Styling: ContentModeElement where Target: ContentModeElement {}
extension Styling: ButtonMenuElement where Target: ButtonMenuElement {}
extension Styling: TextAndIconElement where Target: TextAndIconElement {}
extension Styling: TextInputProperties where Target: TextInput {}
extension Styling: SubmitElement where Target: SubmitElement {}
extension Styling: RangeElement where Target: RangeElement {}

// And each control's own properties.

extension Styling: ButtonProperties where Target == Button {}
extension Styling: ColorPickerProperties where Target == ColorPicker {}
extension Styling: DatePickerProperties where Target == DatePicker {}
extension Styling: TextEditorProperties where Target == TextEditor {}
extension Styling: TextFieldProperties where Target == TextField {}
extension Styling: GridProperties where Target == Grid {}
extension Styling: ImageProperties where Target == Image {}
extension Styling: TextProperties where Target == Text {}
extension Styling: MapProperties where Target == Map {}
extension Styling: PointsShape where Target: PointsShape {}
extension Styling: RectangleProperties where Target == Rectangle {}
extension Styling: ScrollViewProperties where Target == ScrollView {}
extension Styling: StepperProperties where Target == Stepper {}
extension Styling: TimePickerProperties where Target == TimePicker {}
extension Styling: WebViewProperties where Target == WebView {}
extension Styling: ToolbarGroupProperties where Target == ToolbarGroup {}
