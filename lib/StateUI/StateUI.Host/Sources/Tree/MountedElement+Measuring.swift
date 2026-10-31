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
        .opacity, .background, .textColor, .placeholderColor, .tint, .isEnabled,
        .isOn, .value, .minimum, .maximum, .progress, .cursorPosition, .selectionLength,
        .stroke, .fill, .lineWidth, .dash, .dashPhase, .lineCap, .lineJoin,
        .miterLimit, .shape, .cornerRadius, .geometryTransform, .barBackground, .barForegroundColor,
        .drawing, .scrollOffset, .clipsContent, .ignoresInput, .letsInputThrough, .parameters,
    ]).union(transformProperties).union(accessibilityProperties)

    /// Where this element's size may change, the elements whose layouts forget what they measured - this one and
    /// every one above it - and the ItemsView entry the walk stops at, its cell measuring it again: a list's own size
    /// never follows its items.
    public func measuredUpward() -> (layouts: [MountedElement], entry: MountedElement?) {
        var layouts: [MountedElement] = []
        var each: MountedElement? = self
        while let element = each {
            if element.parent?.type == .itemsView { return (layouts, element) }
            layouts.append(element)
            each = element.parent
        }
        return (layouts, nil)
    }
}
