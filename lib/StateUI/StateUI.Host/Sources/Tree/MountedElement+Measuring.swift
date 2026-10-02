// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// Which of an element's properties its layouts read, the same on every host.
/// Design: docs/design/host/layout.md#measured-once
extension MountedElement {
    /// The properties a parent reads into its child's place: a change arranges the parent again.
    public static let arrangedProperties: Set<Prop> = [
        .margin, .horizontalAlignment, .verticalAlignment,
        .width, .height,
        .minimumWidth, .minimumHeight,
        .maximumWidth, .maximumHeight,
        .isVisible,
        .gridRow, .gridColumn, .gridRowSpan, .gridColumnSpan,
        .area,
    ]

    /// The properties drawn without changing any measurement; any other one measures the element again.
    public static let unmeasuredProperties = Set<Prop>([
        .opacity, .background, .textColor, .placeholderColor, .tint, .color, .isEnabled,
        .isOn, .value, .minimum, .maximum, .progress, .cursorPosition, .selectionLength,
        .stroke, .fill, .lineWidth, .dash, .dashPhase, .lineCap, .lineJoin,
        .miterLimit, .shape, .cornerRadius, .geometryTransform, .barBackgroundColor, .barForegroundColor,
        .drawing, .scrollOffset, .clipsContent, .ignoresInput, .letsInputThrough,
    ]).union(transformProperties).union(accessibilityProperties)
}
