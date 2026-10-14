// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A shape enclosing an area its fill paints - every shape but a line.
public enum FilledShapeContract: Contract {
    /// The tier's name.
    public static let name = "FilledShape"

    /// A filled shape is a shape.
    public static let tiers: [any Contract.Type] = [ShapeContract.self]

    /// What the inside of the shape is painted with.
    public static let fill = ElementProperty<Self, Brush>("fill", layer: .stateUI)

    /// The tier's own members.
    public static let members: [any ContractMember] = [fill]
}
