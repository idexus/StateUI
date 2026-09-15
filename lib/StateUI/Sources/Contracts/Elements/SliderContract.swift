// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A value picked by dragging a thumb along a native track.
public enum SliderContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = .slider

    /// Every base host presents it with its native control.
    public static let layer: ElementLayer = .native

    /// A slider is a view, tinted.
    public static let tiers: [any Contract.Type] = [ViewContract.self, TintElementContract.self]

    /// The thumb was let go.
    public static let dragCompleted = ElementEvent<Self, Void>("dragCompleted", layer: .native)

    /// The thumb was grabbed.
    public static let dragStarted = ElementEvent<Self, Void>("dragStarted", layer: .native)

    /// The value at the far end of the track.
    public static let maximum = ElementProperty<Self, Double>("maximum", layer: .native, travels: false)

    /// The value at the near end of the track.
    public static let minimum = ElementProperty<Self, Double>("minimum", layer: .native, travels: false)

    /// Where the thumb stands, between the minimum and the maximum.
    public static let value = ElementProperty<Self, Double>("value", layer: .native)

    /// The thumb was dragged, to the value it carries.
    public static let valueChanged = ElementEvent<Self, Double>("valueChanged", layer: .native)

    /// The element's own members.
    public static let members: [any ContractMember] = [
        dragCompleted, dragStarted, maximum, minimum, value, valueChanged,
    ]
}
