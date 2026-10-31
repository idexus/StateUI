// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A control a style can be written for, and every control that is one.
// Design: docs/design/views/styles.md#what-can-be-styled

/// A control a style can be written for - a view, or an item on a bar: one with an initializer that sets nothing,
/// from which the style takes its node type.
public protocol StyleTarget: PropertyContainer {
    /// A control with nothing set. Where a style reads its target's type.
    init()
}

extension StyleTarget {
    /// The keyed style from the application's style sheet that this control wears; nil wears the style without a
    /// key, which applies to every control of its type by itself.
    ///
    ///     Text("Welcome").style(.headline)
    ///     Button("Save").style(plain ? .platform : nil)
    public func style(_ key: StyleKey<Self>?) -> Modified {
        guard let key else { return modified { $0.props[VisualElementContract.style.token] = nil } }
        return setValue(VisualElementContract.style, Name(key.name))
    }
}

extension Text: StyleTarget {}
extension Button: StyleTarget {}
extension Link: StyleTarget {}
extension ColorPicker: StyleTarget {}
extension TextField: StyleTarget {}
extension TextEditor: StyleTarget {}
extension Picker: StyleTarget {}
extension DatePicker: StyleTarget {}
extension TimePicker: StyleTarget {}
extension Switch: StyleTarget {}
extension CheckBox: StyleTarget {}
extension Slider: StyleTarget {}
extension Stepper: StyleTarget {}
extension SearchField: StyleTarget {}
extension Spinner: StyleTarget {}
extension ProgressBar: StyleTarget {}
extension Image: StyleTarget {}
extension Separator: StyleTarget {}
extension Space: StyleTarget {}
extension Fill: StyleTarget {}
extension Grid: StyleTarget {}
extension ScrollView: StyleTarget {}
extension VStack: StyleTarget {}
extension HStack: StyleTarget {}
extension ZStack: StyleTarget {}
extension Rectangle: StyleTarget {}
extension Ellipse: StyleTarget {}
extension Capsule: StyleTarget {}
extension Line: StyleTarget {}
extension Path: StyleTarget {}
extension Polygon: StyleTarget {}
extension Polyline: StyleTarget {}
extension Canvas: StyleTarget {}
extension WebView: StyleTarget {}
extension Map: StyleTarget {}
extension ToolbarButton: StyleTarget {}
extension ToolbarToggle: StyleTarget {}
extension ToolbarGroup: StyleTarget {}
