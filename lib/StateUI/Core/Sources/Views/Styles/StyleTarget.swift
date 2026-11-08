// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A control a style can be written for, and every control that is one.
// Design: docs/design/views/styles.md#what-can-be-styled

/// A control a style can be written for - a view, or an item on a bar - named by its node type, which a style
/// resolves by.
public protocol StyleTarget: PropertyContainer {
    /// The node type every control of this kind is described with: what a style of it names.
    static var nodeType: NodeType { get }
}

extension StyleTarget {
    /// The keyed style from the application's style sheet that this control wears; nil wears the style without a
    /// key, which applies to every control of its type by itself.
    ///
    ///     Text("Welcome").style(.headline)
    ///     Button("Save").style(plain ? .platform : nil)
    public func style(_ key: StyleKey<Self>?) -> Modified {
        guard let key else { return modified { $0.props[StyledElementContract.style.token] = nil } }
        return setValue(StyledElementContract.style, Name(key.name))
    }
}

extension Text: StyleTarget {
    /// Text's node type.
    public static var nodeType: NodeType { TextContract.nodeType }
}
extension Button: StyleTarget {
    /// Button's node type.
    public static var nodeType: NodeType { ButtonContract.nodeType }
}
extension Link: StyleTarget {
    /// Link's node type.
    public static var nodeType: NodeType { LinkContract.nodeType }
}
extension ColorPicker: StyleTarget {
    /// ColorPicker's node type.
    public static var nodeType: NodeType { ColorPickerContract.nodeType }
}
extension TextField: StyleTarget {
    /// TextField's node type.
    public static var nodeType: NodeType { TextFieldContract.nodeType }
}
extension TextEditor: StyleTarget {
    /// TextEditor's node type.
    public static var nodeType: NodeType { TextEditorContract.nodeType }
}
extension Picker: StyleTarget {
    /// Picker's node type.
    public static var nodeType: NodeType { PickerContract.nodeType }
}
extension DatePicker: StyleTarget {
    /// DatePicker's node type.
    public static var nodeType: NodeType { DatePickerContract.nodeType }
}
extension TimePicker: StyleTarget {
    /// TimePicker's node type.
    public static var nodeType: NodeType { TimePickerContract.nodeType }
}
extension Switch: StyleTarget {
    /// Switch's node type.
    public static var nodeType: NodeType { SwitchContract.nodeType }
}
extension CheckBox: StyleTarget {
    /// CheckBox's node type.
    public static var nodeType: NodeType { CheckBoxContract.nodeType }
}
extension Slider: StyleTarget {
    /// Slider's node type.
    public static var nodeType: NodeType { SliderContract.nodeType }
}
extension Stepper: StyleTarget {
    /// Stepper's node type.
    public static var nodeType: NodeType { StepperContract.nodeType }
}
extension SearchField: StyleTarget {
    /// SearchField's node type.
    public static var nodeType: NodeType { SearchFieldContract.nodeType }
}
extension Spinner: StyleTarget {
    /// Spinner's node type.
    public static var nodeType: NodeType { SpinnerContract.nodeType }
}
extension ProgressBar: StyleTarget {
    /// ProgressBar's node type.
    public static var nodeType: NodeType { ProgressBarContract.nodeType }
}
extension Image: StyleTarget {
    /// Image's node type.
    public static var nodeType: NodeType { ImageContract.nodeType }
}
extension Separator: StyleTarget {
    /// Separator's node type.
    public static var nodeType: NodeType { SeparatorContract.nodeType }
}
extension Space: StyleTarget {
    /// Space's node type.
    public static var nodeType: NodeType { SpaceContract.nodeType }
}
extension Fill: StyleTarget {
    /// Fill's node type.
    public static var nodeType: NodeType { FillContract.nodeType }
}
extension Grid: StyleTarget {
    /// Grid's node type.
    public static var nodeType: NodeType { GridContract.nodeType }
}
extension ScrollView: StyleTarget {
    /// ScrollView's node type.
    public static var nodeType: NodeType { ScrollViewContract.nodeType }
}
extension VStack: StyleTarget {
    /// VStack's node type.
    public static var nodeType: NodeType { VStackContract.nodeType }
}
extension HStack: StyleTarget {
    /// HStack's node type.
    public static var nodeType: NodeType { HStackContract.nodeType }
}
extension ZStack: StyleTarget {
    /// ZStack's node type.
    public static var nodeType: NodeType { ZStackContract.nodeType }
}
extension Rectangle: StyleTarget {
    /// Rectangle's node type.
    public static var nodeType: NodeType { RectangleContract.nodeType }
}
extension Ellipse: StyleTarget {
    /// Ellipse's node type.
    public static var nodeType: NodeType { EllipseContract.nodeType }
}
extension Capsule: StyleTarget {
    /// Capsule's node type.
    public static var nodeType: NodeType { CapsuleContract.nodeType }
}
extension Line: StyleTarget {
    /// Line's node type.
    public static var nodeType: NodeType { LineContract.nodeType }
}
extension Path: StyleTarget {
    /// Path's node type.
    public static var nodeType: NodeType { PathContract.nodeType }
}
extension Polygon: StyleTarget {
    /// Polygon's node type.
    public static var nodeType: NodeType { PolygonContract.nodeType }
}
extension Polyline: StyleTarget {
    /// Polyline's node type.
    public static var nodeType: NodeType { PolylineContract.nodeType }
}
extension Canvas: StyleTarget {
    /// Canvas's node type.
    public static var nodeType: NodeType { CanvasContract.nodeType }
}
extension WebView: StyleTarget {
    /// WebView's node type.
    public static var nodeType: NodeType { WebViewContract.nodeType }
}
extension Map: StyleTarget {
    /// Map's node type.
    public static var nodeType: NodeType { MapContract.nodeType }
}
extension ToolbarButton: StyleTarget {
    /// ToolbarButton's node type.
    public static var nodeType: NodeType { ToolbarButtonContract.nodeType }
}
extension ToolbarToggle: StyleTarget {
    /// ToolbarToggle's node type.
    public static var nodeType: NodeType { ToolbarToggleContract.nodeType }
}
extension ToolbarGroup: StyleTarget {
    /// ToolbarGroup's node type.
    public static var nodeType: NodeType { ToolbarGroupContract.nodeType }
}
extension ItemsView: StyleTarget {
    /// A list's node type, whatever its identities are.
    public static var nodeType: NodeType { ItemsViewContract.nodeType }
}
extension MotionLayout: StyleTarget {
    /// A motion layout's node type, whatever its items and parameters are.
    public static var nodeType: NodeType { MotionLayoutContract.nodeType }
}
