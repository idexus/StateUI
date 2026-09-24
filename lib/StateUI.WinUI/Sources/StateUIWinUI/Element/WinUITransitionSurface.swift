// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The closed set of properties the WinUI host moves; any other arrives at once.
/// Design: docs/design/platforms/winui/motion.md#what-moves
@MainActor
enum WinUITransitionSurface {
    /// Whether the host moves `property` on an element of `type`.
    static func presents(_ property: Prop, on type: NodeType) -> Bool {
        if viewTypes.contains(type), viewProperties.contains(property) { return true }

        switch type {
        case .vStack, .hStack: return property == .padding || property == .spacing
        case .slider: return property == .value
        default: return false
        }
    }

    /// Every element the registry makes a view for: each one's view moves the view properties.
    private static let viewTypes = Set(WinUIRegistrations.registry.realization.elements.map { NodeType($0) })

    private static let viewProperties: Set<Prop> = [
        .opacity,
        .width, .height, .minimumWidth, .minimumHeight, .maximumWidth, .maximumHeight,
        .rotation, .scale, .scaleX, .scaleY, .translationX, .translationY,
        .margin,
    ]
}
