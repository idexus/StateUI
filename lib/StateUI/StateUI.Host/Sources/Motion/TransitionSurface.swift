// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The properties a host moves frame by frame, element by element: those its views present and whose values travel.
/// Every other pair arrives at once, rather than keeping a motion alive that nothing shows.
/// Design: docs/design/host/motion.md#what-travels
@_spi(Host) public enum TransitionSurface {
    /// Whether a host moves `property` of an element of `type` frame by frame; `atRest` names, element type by
    /// element type, what the host's toolkit paints only at rest, which arrives at once there.
    public static func presents(_ property: Prop, on type: NodeType, atRest: [NodeType: Set<Prop>] = [:]) -> Bool {
        if atRest[type]?.contains(property) == true {
            return false
        }

        if nativeViewTypes.contains(type), sharedViewProperties.contains(property) {
            return true
        }

        if shapeTypes.contains(type), shapeProperties.contains(property) {
            return true
        }

        switch type {
        case .page:
            return contentPageProperties.contains(property)

        case .vStack, .hStack:
            return stackProperties.contains(property) || layoutBoxProperties.contains(property)

        case .grid:
            return gridProperties.contains(property) || layoutBoxProperties.contains(property)

        case .zStack:
            return property == .padding || layoutBoxProperties.contains(property)

        case .motionLayout, .fill, .space:
            return layoutBoxProperties.contains(property)

        case .scrollView:
            return property == .padding || layoutBoxProperties.contains(property)

        case .text:
            return labelProperties.contains(property)

        case .textSpan:
            return spanProperties.contains(property)

        case .button:
            return buttonProperties.contains(property)


        case .textField, .textEditor, .searchField:
            return fieldProperties.contains(property)

        case .picker:
            return pickerProperties.contains(property)

        case .datePicker, .timePicker:
            return textControlProperties.contains(property)

        case .checkBox:
            return property == .tint

        case .slider:
            return sliderProperties.contains(property)

        case .progressBar:
            return property == .progress

        case .navigationStack, .tabView, .splitView:
            return barProperties.contains(property)

        case .rectangle:
            return property == .cornerRadius

        case .line:
            return lineProperties.contains(property)

        case .canvas:
            return property == .drawing

        case .window:
            return windowProperties.contains(property)

        default:
            return false
        }
    }

    private static let nativeViewTypes: Set<NodeType> = [
        .spinner, .button,
        .checkBox, .datePicker, .textEditor, .ellipse, .textField, .canvas,
        .grid, .hStack, .image, .itemsView, .text, .line,
        .path, .picker, .polygon, .polyline, .progressBar,
        .rectangle, .scrollView, .searchField, .slider,
        .stepper, .switch, .timePicker, .vStack, .zStack, .motionLayout, .fill, .space,
    ]

    private static let shapeTypes: Set<NodeType> = [
        .ellipse, .line, .path, .polygon, .polyline, .rectangle,
    ]

    private static let sharedViewProperties: Set<Prop> = [
        .opacity, .background,
        VisualElementContract.width.token, VisualElementContract.height.token,
        VisualElementContract.minimumWidth.token, VisualElementContract.minimumHeight.token,
        VisualElementContract.maximumWidth.token, VisualElementContract.maximumHeight.token,
        .rotation, .rotationX, .rotationY, .scale, .scaleX, .scaleY, .translationX, .translationY,
        .margin,
    ]

    private static let contentPageProperties: Set<Prop> = [.background]

    private static let stackProperties: Set<Prop> = [.padding, StackContract.spacing.token]

    /// What a layout, a space or a fill draws of its own box.
    private static let layoutBoxProperties: Set<Prop> = [
        .background, BorderElementContract.stroke.token, BorderElementContract.lineWidth.token, .shape,
    ]

    private static let gridProperties: Set<Prop> = [
        .padding, GridContract.rowSpacing.token, .columnSpacing, .rows, .columns,
    ]

    private static let labelProperties: Set<Prop> = [
        .padding, .fontSize, .textColor, .tracking, .lineHeight,
    ]

    private static let spanProperties: Set<Prop> = [
        .background, .fontSize, .textColor, .tracking, .lineHeight,
    ]

    private static let textControlProperties: Set<Prop> = [.fontSize, .textColor]

    private static let buttonProperties: Set<Prop> = [
        .padding, .fontSize, .textColor, BorderElementContract.stroke.token, BorderElementContract.lineWidth.token,
        .shape,
    ]


    private static let fieldProperties: Set<Prop> = [
        .fontSize, .textColor, .placeholderColor,
    ]


    private static let pickerProperties: Set<Prop> = [.fontSize, .textColor, .tint]

    private static let sliderProperties: Set<Prop> = [.value, .tint]

    private static let barProperties: Set<Prop> = [.barBackground, .barForegroundColor]

    private static let shapeProperties: Set<Prop> = [
        .fill, ShapeContract.stroke.token, ShapeContract.lineWidth.token, .dashPhase, .miterLimit,
        .geometryTransform,
    ]

    private static let lineProperties: Set<Prop> = [.from, .to]

    private static let windowProperties: Set<Prop> = [.x, .y, WindowContract.width.token, WindowContract.height.token]
}
