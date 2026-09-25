// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A control a style can be written for, and every control that is one.
// Design: docs/design/views/styles.md#what-can-be-styled

/// A control a style can be written for: one with an initializer that sets
/// nothing, from which the style takes its node type.
public protocol StyleTarget: VisualElement {
    /// A control with nothing set. Where a style reads its target's type.
    init()
}

extension Label: StyleTarget {}
extension Button: StyleTarget {}
extension TextField: StyleTarget {}
extension TextEditor: StyleTarget {}
extension Picker: StyleTarget {}
extension DatePicker: StyleTarget {}
extension TimePicker: StyleTarget {}
extension Switch: StyleTarget {}
extension CheckBox: StyleTarget {}
extension RadioButton: StyleTarget {}
extension Slider: StyleTarget {}
extension Stepper: StyleTarget {}
extension SearchField: StyleTarget {}
extension ActivityIndicator: StyleTarget {}
extension ProgressBar: StyleTarget {}
extension Image: StyleTarget {}
extension ColorBox: StyleTarget {}
extension Grid: StyleTarget {}
extension ScrollView: StyleTarget {}
extension VStack: StyleTarget {}
extension HStack: StyleTarget {}
extension ZStack: StyleTarget {}
extension Rectangle: StyleTarget {}
extension Ellipse: StyleTarget {}
extension Line: StyleTarget {}
extension Path: StyleTarget {}
extension Polygon: StyleTarget {}
extension Polyline: StyleTarget {}
extension Canvas: StyleTarget {}
extension PositionIndicator: StyleTarget {}
extension WebView: StyleTarget {}
extension Map: StyleTarget {}
extension TitleBar: StyleTarget {}
