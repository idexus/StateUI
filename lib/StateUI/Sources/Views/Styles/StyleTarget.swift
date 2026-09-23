// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A control a style can be written for, and every control that is one.
// Design: docs/design/views/styles.md#what-can-be-styled

/// A control a style can be written for: one with an initializer that sets
/// nothing, from which the style takes its node type.
public protocol StyleTarget: VisualElement {
    /// A control with nothing set. Where a style reads its target's type.
    init()

    /// The state a control of this type rests in, given to a group of states
    /// that names none so it has somewhere to return to: `.normal` for
    /// everything but a RadioButton.
    static var restingVisualState: VisualState<Self> { get }
}

extension StyleTarget {
    /// Where nearly everything rests: an enabled, unfocused, un-hovered control
    /// is in Normal.
    public static var restingVisualState: VisualState<Self> { .normal }
}

extension RadioButton {
    /// Unchecked, not Normal - see the note on `VisualState.unchecked`.
    public static var restingVisualState: VisualState<RadioButton> { .unchecked }
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
extension Border: StyleTarget {}
extension Grid: StyleTarget {}
extension ScrollView: StyleTarget {}
extension VStack: StyleTarget {}
extension HStack: StyleTarget {}
extension AbsoluteLayout: StyleTarget {}
extension RefreshView: StyleTarget {}
extension SwipeView: StyleTarget {}
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

// A SwipeAction is a menu item, not a view, and has nothing to style.
