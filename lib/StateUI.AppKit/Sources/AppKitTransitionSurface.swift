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

        case .border:
            return borderProperties.contains(property)

        case .vStack, .hStack:
            return stackProperties.contains(property)

        case .grid:
            return gridProperties.contains(property)

        case .scrollView:
            return property == .padding

        case .label:
            return labelProperties.contains(property)

        case .span:
            return spanProperties.contains(property)

        case .button:
            return buttonProperties.contains(property)

        case .imageButton:
            return imageButtonProperties.contains(property)

        case .entry, .editor, .searchBar:
            return fieldProperties.contains(property)

        case .radioButton:
            return radioProperties.contains(property)

        case .picker:
            return pickerProperties.contains(property)

        case .datePicker, .timePicker:
            return textControlProperties.contains(property)

        case .boxView:
            return boxProperties.contains(property)

        case .checkBox:
            return property == .color

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
            return rectangleProperties.contains(property)

        case .roundRectangle:
            return property == .cornerRadius

        case .line:
            return lineProperties.contains(property)

        case .graphicsView:
            return property == .drawable

        case .window:
            return windowProperties.contains(property)

        default:
            return false
        }
    }

    private static let nativeViewTypes: Set<NodeType> = [
        .absoluteLayout, .activityIndicator, .border, .boxView, .button,
        .checkBox, .datePicker, .editor, .ellipse, .entry, .graphicsView,
        .grid, .hStack, .image, .imageButton, .label, .line,
        .path, .picker, .polygon, .polyline, .progressBar, .radioButton,
        .rectangle, .roundRectangle, .scrollView, .searchBar, .slider,
        .stepper, .switch, .timePicker, .vStack,
    ]

    private static let shapeTypes: Set<NodeType> = [
        .ellipse, .line, .path, .polygon, .polyline, .rectangle, .roundRectangle,
    ]

    private static let sharedViewProperties: Set<Prop> = [
        .opacity, .backgroundColor,
        .widthRequest, .heightRequest,
        .minimumWidthRequest, .minimumHeightRequest,
        .maximumWidthRequest, .maximumHeightRequest,
        .rotation, .scale, .scaleX, .scaleY, .translationX, .translationY,
        .margin,
    ]

    private static let contentPageProperties: Set<Prop> = [
        .backgroundColor, .padding,
    ]

    private static let borderProperties: Set<Prop> = [
        .padding, .background, .stroke, .strokeThickness, .strokeShape,
    ]

    private static let stackProperties: Set<Prop> = [.padding, .spacing]

    private static let gridProperties: Set<Prop> = [
        .padding, .rowSpacing, .columnSpacing, .rowDefinitions, .columnDefinitions,
    ]

    private static let labelProperties: Set<Prop> = [
        .padding, .fontSize, .textColor, .characterSpacing, .lineHeight,
    ]

    private static let spanProperties: Set<Prop> = [
        .backgroundColor, .fontSize, .textColor, .characterSpacing, .lineHeight,
    ]

    private static let textControlProperties: Set<Prop> = [.fontSize, .textColor]

    private static let buttonProperties: Set<Prop> = [
        .padding, .fontSize, .textColor, .borderColor, .borderWidth, .cornerRadius,
    ]

    private static let imageButtonProperties: Set<Prop> = [
        .padding, .borderColor, .borderWidth, .cornerRadius,
    ]

    private static let fieldProperties: Set<Prop> = [
        .fontSize, .textColor, .placeholderColor,
    ]

    private static let radioProperties: Set<Prop> = [.padding, .fontSize, .textColor]

    private static let pickerProperties: Set<Prop> = [.fontSize, .textColor, .titleColor]

    private static let boxProperties: Set<Prop> = [.color, .cornerRadius]

    private static let sliderProperties: Set<Prop> = [.value, .minimumTrackColor]

    private static let navigationProperties: Set<Prop> = [
        .barBackgroundColor, .barTextColor,
    ]

    private static let titleBarProperties: Set<Prop> = [
        .backgroundColor, .foregroundColor,
    ]

    private static let shapeProperties: Set<Prop> = [
        .fill, .stroke, .strokeThickness, .strokeDashOffset, .strokeMiterLimit,
        .renderTransform,
    ]

    private static let rectangleProperties: Set<Prop> = [.radiusX, .radiusY]

    private static let lineProperties: Set<Prop> = [.x1, .y1, .x2, .y2]

    private static let windowProperties: Set<Prop> = [.x, .y, .width, .height]
}

#endif
