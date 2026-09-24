// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
@_spi(Host) import StateUI

/// The closed set of property presentations the AppKit host can move.
///
/// StateUI's property vocabulary is open, while a native host can interpolate
/// only values it actually presents. Unknown control/property pairs therefore
/// snap to their committed target instead of keeping an invisible display
/// channel alive.
enum AppKitTransitionSurface {
    static func presents(_ property: Prop, on type: NodeType) -> Bool {
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

        case .scrollView:
            return property == .padding || layoutBoxProperties.contains(property)

        case .label:
            return labelProperties.contains(property)

        case .span:
            return spanProperties.contains(property)

        case .button:
            return buttonProperties.contains(property)


        case .textField, .textEditor, .searchField:
            return fieldProperties.contains(property)

        case .radioButton:
            return radioProperties.contains(property)

        case .picker:
            return pickerProperties.contains(property)

        case .datePicker, .timePicker:
            return textControlProperties.contains(property)

        case .colorBox:
            return boxProperties.contains(property)

        case .checkBox:
            return property == .tint

        case .slider:
            return sliderProperties.contains(property)

        case .progressBar:
            return property == .progress

        case .navigationStack:
            return navigationProperties.contains(property)

        case .tabbedView:
            return property == .barBackgroundColor

        case .titleBar:
            return titleBarProperties.contains(property)

        case .rectangle:
            return property == .cornerRadius

        case .line:
            return lineProperties.contains(property)

        case .canvas:
            return property == .drawable

        case .window:
            return windowProperties.contains(property)

        default:
            return false
        }
    }

    private static let nativeViewTypes: Set<NodeType> = [
        .activityIndicator, .colorBox, .button,
        .checkBox, .datePicker, .textEditor, .ellipse, .textField, .canvas,
        .grid, .hStack, .image, .label, .line,
        .path, .picker, .polygon, .polyline, .progressBar, .radioButton,
        .rectangle, .scrollView, .searchField, .slider,
        .stepper, .switch, .timePicker, .vStack, .zStack,
    ]

    private static let shapeTypes: Set<NodeType> = [
        .ellipse, .line, .path, .polygon, .polyline, .rectangle,
    ]

    private static let sharedViewProperties: Set<Prop> = [
        .opacity, .background,
        .width, .height,
        .minimumWidth, .minimumHeight,
        .maximumWidth, .maximumHeight,
        .rotation, .scale, .scaleX, .scaleY, .translationX, .translationY,
        .margin,
    ]

    private static let contentPageProperties: Set<Prop> = [
        .background, .padding,
    ]

    private static let stackProperties: Set<Prop> = [.padding, .spacing]

    /// What a layout draws of its own box.
    private static let layoutBoxProperties: Set<Prop> = [.background, .stroke, .strokeWidth, .shape]

    private static let gridProperties: Set<Prop> = [
        .padding, .rowSpacing, .columnSpacing, .rows, .columns,
    ]

    private static let labelProperties: Set<Prop> = [
        .padding, .fontSize, .textColor, .characterSpacing, .lineHeight,
    ]

    private static let spanProperties: Set<Prop> = [
        .background, .fontSize, .textColor, .characterSpacing, .lineHeight,
    ]

    private static let textControlProperties: Set<Prop> = [.fontSize, .textColor]

    private static let buttonProperties: Set<Prop> = [
        .padding, .fontSize, .textColor, .borderColor, .borderWidth, .cornerRadius,
    ]


    private static let fieldProperties: Set<Prop> = [
        .fontSize, .textColor, .placeholderColor,
    ]

    private static let radioProperties: Set<Prop> = [.padding, .fontSize, .textColor]

    private static let pickerProperties: Set<Prop> = [.fontSize, .textColor, .tint]

    private static let boxProperties: Set<Prop> = [.color, .cornerRadius]

    private static let sliderProperties: Set<Prop> = [.value, .tint]

    private static let navigationProperties: Set<Prop> = [
        .barBackgroundColor, .barForegroundColor,
    ]

    private static let titleBarProperties: Set<Prop> = [
        .background, .barForegroundColor,
    ]

    private static let shapeProperties: Set<Prop> = [
        .fill, .stroke, .strokeWidth, .strokeDashOffset, .strokeMiterLimit,
        .renderTransform,
    ]

    private static let lineProperties: Set<Prop> = [.x1, .y1, .x2, .y2]

    private static let windowProperties: Set<Prop> = [.x, .y, .width, .height]
}

#endif
