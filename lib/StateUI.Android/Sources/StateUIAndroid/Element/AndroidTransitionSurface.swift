// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The closed set of properties the Android Views host moves; any other arrives at once.
/// Design: docs/design/platforms/android/motion.md#what-moves
enum AndroidTransitionSurface {
    /// Whether the host moves `property` on an element of `type`.
    static func presents(_ property: Prop, on type: NodeType) -> Bool {
        if viewTypes.contains(type), viewProperties.contains(property) { return true }

        switch type {
        case .page: return property == .background
        case .vStack, .hStack: return property == .padding || property == .spacing
        case .grid: return [.padding, .rowSpacing, .columnSpacing, .rows, .columns].contains(property)
        case .border: return [.padding, .stroke, .strokeWidth, .shape].contains(property)
        case .colorBox: return property == .color || property == .cornerRadius
        case .label: return [.fontSize, .textColor, .padding, .characterSpacing, .lineHeight].contains(property)
        case .button: return property == .fontSize || property == .textColor || property == .padding
        case .progressBar: return property == .progress
        case .textField: return property == .fontSize || property == .textColor || property == .placeholderColor
        case .slider: return property == .value || property == .tint
        default: return false
        }
    }

    private static let viewTypes: Set<NodeType> = [
        .label, .button, .textField, .switch, .slider, .vStack, .hStack,
        .grid, .absoluteLayout, .border, .colorBox, .image, .scrollView, .progressBar, .activityIndicator, .stepper,
    ]

    private static let viewProperties: Set<Prop> = [
        .opacity, .background,
        .width, .height, .minimumWidth, .minimumHeight, .maximumWidth, .maximumHeight,
        .rotation, .scale, .scaleX, .scaleY, .translationX, .translationY,
        .margin,
    ]
}
