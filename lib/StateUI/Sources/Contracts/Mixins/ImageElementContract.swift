// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// How a picture fills the room it was given.
public enum ImageElementContract: Contract {
    /// The tier's name.
    public static let name = "ImageElement"

    /// A picture's fit is carried as a value in the tree.
    public static let tiers: [any Contract.Type] = [PropertyContainerContract.self]

    /// How the picture fills its room when the two are not the same shape.
    public static let aspect = ElementProperty<Self, Aspect>("aspect", layer: .native)

    /// The tier's own members.
    public static let members: [any ContractMember] = [aspect]
}
