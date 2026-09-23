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
        case .label, .button: return property == .fontSize || property == .textColor
        case .textField: return property == .fontSize || property == .textColor || property == .placeholderColor
        case .slider: return property == .value || property == .tint
        default: return false
        }
    }

    private static let viewTypes: Set<NodeType> = [
        .label, .button, .textField, .switch, .slider, .vStack, .hStack,
    ]

    private static let viewProperties: Set<Prop> = [
        .opacity, .background,
        .width, .height, .minimumWidth, .minimumHeight, .maximumWidth, .maximumHeight,
        .rotation, .scale, .scaleX, .scaleY, .translationX, .translationY,
        .margin,
    ]
}
