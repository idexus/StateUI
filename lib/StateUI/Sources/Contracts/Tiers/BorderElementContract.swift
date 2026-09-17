// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The line around a control's own box, and how round its corners are.
public enum BorderElementContract: Contract {
    /// The tier's name.
    public static let name = "BorderElement"

    /// A border is carried as values in the tree.
    public static let tiers: [any Contract.Type] = [PropertyContainerContract.self]

    /// The colour of the line around the control.
    public static let borderColor = ElementProperty<Self, Color>("borderColor", layer: .native)

    /// How thick the line around the control is.
    public static let borderWidth = ElementProperty<Self, Double>("borderWidth", layer: .native, moves: .size)

    /// How round the control's corners are, in device units.
    public static let cornerRadius = ElementProperty<Self, Int>("cornerRadius", layer: .native, moves: .size)

    /// The tier's own members.
    public static let members: [any ContractMember] = [borderColor, borderWidth, cornerRadius]
}
