// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a control choosing a number in a range holds and reports: a slider, a stepper.
public enum RangeElementContract: Tier {
    /// The tier's own name.
    public static let name = "RangeElement"

    /// Where it stands, between the minimum and the maximum.
    public static let value = ElementProperty<Self, Double>("value", layer: .native)

    /// The user changed it, to the value it carries.
    public static let valueChanged = ElementEvent<Self, Double>("valueChanged", layer: .native)

    /// The least value it takes.
    public static let minimum = ElementProperty<Self, Double>("minimum", layer: .native, travels: false)

    /// The greatest value it takes.
    public static let maximum = ElementProperty<Self, Double>("maximum", layer: .native, travels: false)

    /// The tier's own members.
    public static let members: [any ContractMember] = [value, valueChanged, minimum, maximum]
}
