// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A number changed one step at a time, by two buttons.
public enum StepperContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "Stepper"

    /// Every base host presents it with its native control.
    public static let layer: ElementLayer = .native

    /// A stepper is a view.
    public static let tiers: [any Contract.Type] = [ViewContract.self]

    /// The highest it goes.
    public static let maximum = ElementProperty<Self, Double>("maximum", layer: .native, travels: false)

    /// The lowest it goes.
    public static let minimum = ElementProperty<Self, Double>("minimum", layer: .native, travels: false)

    /// How far one tap moves the value.
    public static let step = ElementProperty<Self, Double>("step", layer: .native, travels: false)

    /// The number it shows, between the minimum and the maximum.
    public static let value = ElementProperty<Self, Double>("value", layer: .native)

    /// A button was tapped, stepping to the value it carries.
    public static let valueChanged = ElementEvent<Self, Double>("valueChanged", layer: .native)

    /// The element's own members.
    public static let members: [any ContractMember] = [maximum, minimum, step, value, valueChanged]
}
