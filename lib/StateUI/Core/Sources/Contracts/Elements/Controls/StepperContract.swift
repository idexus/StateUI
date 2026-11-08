// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A number changed one step at a time, by two buttons.
public enum StepperContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "Stepper"

    /// Every base host presents it with its native control.
    public static let layer: ElementLayer = .native

    /// A stepper is a view.
    public static let tiers: [any Tier.Type] = [ViewContract.self, FocusElementContract.self, RangeElementContract.self]

    /// How far one tap moves the value.
    public static let step = ElementProperty<Self, Double>("step", layer: .native, travels: false)

    /// The element's own members.
    public static let members: [any ContractMember] = [step]
}
