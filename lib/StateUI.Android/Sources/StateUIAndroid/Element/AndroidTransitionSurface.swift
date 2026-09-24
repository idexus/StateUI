// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The closed set of properties the Android Views host moves; any other arrives at once.
/// Design: docs/design/platforms/android/motion.md#what-moves
@MainActor
enum AndroidTransitionSurface {
    /// Whether the host moves `property` on an element of `type`.
    static func presents(_ property: Prop, on type: NodeType) -> Bool {
        if viewTypes.contains(type), viewProperties.contains(property) { return true }

        switch type {
        case .page: return property == .background
        case .vStack, .hStack: return [.padding, .spacing, .stroke, .strokeWidth, .shape].contains(property)
        case .grid: return [.padding, .rowSpacing, .columnSpacing, .rows, .columns, .stroke, .strokeWidth, .shape]
            .contains(property)
        case .zStack: return [.padding, .stroke, .strokeWidth, .shape].contains(property)
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

    /// Every element the registry makes a view for: each one's view moves the view properties.
    private static let viewTypes = Set(AndroidRegistrations.registry.realization.elements.map { NodeType($0) })

    private static let viewProperties: Set<Prop> = [
        .opacity, .background,
        .width, .height, .minimumWidth, .minimumHeight, .maximumWidth, .maximumHeight,
        .rotation, .scale, .scaleX, .scaleY, .translationX, .translationY,
        .margin,
    ]
}
