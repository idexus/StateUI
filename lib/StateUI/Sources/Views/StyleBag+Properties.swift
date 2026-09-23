// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What a style may say: the property half of each tier its target wears,
// and its target's own properties.
// Design: docs/design/views/tiers.md#two-halves

extension StyleBag: VisualElementProperties {}
extension StyleBag: ViewProperties where Target: View {}
extension StyleBag: LayoutProperties where Target: Layout {}
extension StyleBag: StackBaseProperties where Target: StackBase {}
extension StyleBag: ShapeProperties where Target: Shape {}
extension StyleBag: PaddingElement where Target: PaddingElement {}
extension StyleBag: TextStyleElement where Target: TextStyleElement {}
extension StyleBag: TextElement where Target: TextElement {}
extension StyleBag: FontElement where Target: FontElement {}
extension StyleBag: TintElement where Target: TintElement {}
extension StyleBag: TextAlignmentElement where Target: TextAlignmentElement {}
extension StyleBag: LineHeightElement where Target: LineHeightElement {}
extension StyleBag: DecorableTextElement where Target: DecorableTextElement {}
extension StyleBag: BorderElement where Target: BorderElement {}
extension StyleBag: ImageElement where Target: ImageElement {}
extension StyleBag: InputViewProperties where Target: InputView {}

// And each control's own properties.

extension StyleBag: ActivityIndicatorProperties where Target == ActivityIndicator {}
extension StyleBag: BorderProperties where Target == Border {}
extension StyleBag: ColorBoxProperties where Target == ColorBox {}
extension StyleBag: ButtonProperties where Target == Button {}
extension StyleBag: CheckBoxProperties where Target == CheckBox {}
extension StyleBag: DatePickerProperties where Target == DatePicker {}
extension StyleBag: TextEditorProperties where Target == TextEditor {}
extension StyleBag: TextFieldProperties where Target == TextField {}
extension StyleBag: CanvasProperties where Target == Canvas {}
extension StyleBag: GridProperties where Target == Grid {}
extension StyleBag: ImageProperties where Target == Image {}
extension StyleBag: PositionIndicatorProperties where Target == PositionIndicator {}
extension StyleBag: LabelProperties where Target == Label {}
extension StyleBag: LineProperties where Target == Line {}
extension StyleBag: MapProperties where Target == Map {}
extension StyleBag: PathProperties where Target == Path {}
extension StyleBag: PickerProperties where Target == Picker {}
extension StyleBag: PolygonProperties where Target == Polygon {}
extension StyleBag: PolylineProperties where Target == Polyline {}
extension StyleBag: ProgressBarProperties where Target == ProgressBar {}
extension StyleBag: RadioButtonProperties where Target == RadioButton {}
extension StyleBag: RectangleProperties where Target == Rectangle {}
extension StyleBag: RefreshViewProperties where Target == RefreshView {}
extension StyleBag: ScrollViewProperties where Target == ScrollView {}
extension StyleBag: SearchFieldProperties where Target == SearchField {}
extension StyleBag: SliderProperties where Target == Slider {}
extension StyleBag: StepperProperties where Target == Stepper {}
extension StyleBag: SwipeViewProperties where Target == SwipeView {}
extension StyleBag: SwitchProperties where Target == Switch {}
extension StyleBag: TimePickerProperties where Target == TimePicker {}
extension StyleBag: TitleBarProperties where Target == TitleBar {}
extension StyleBag: WebViewProperties where Target == WebView {}
