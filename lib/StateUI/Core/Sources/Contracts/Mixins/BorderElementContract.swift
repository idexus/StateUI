// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What an element draws of its own box: what lets what lies behind it show through, the shape its backdrop, its
/// background, its outline and its cut follow, and the outline.
public enum BorderElementContract: Contract {
    /// The tier's name.
    public static let name = "BorderElement"

    /// A border is carried as values in the tree.
    public static let tiers: [any Contract.Type] = [PropertyContainerContract.self]

    /// What lets what lies behind the element show through its box: a material, or the platform's glass, under its
    /// background.
    public static let backdrop = ElementProperty<Self, Backdrop>("backdrop", layer: .adaptive)

    /// The shape the element's backdrop, its background, its outline and - where it clips - what it holds follow.
    public static let shape = ElementProperty<Self, ContainerShape>("shape", layer: .stateUI)

    /// What the outline is painted with.
    public static let stroke = ElementProperty<Self, Brush>("stroke", layer: .stateUI)

    /// How wide the outline is drawn, in device units.
    public static let lineWidth = ElementProperty<Self, Double>("lineWidth", layer: .stateUI, moves: .size)

    /// The tier's own members.
    public static let members: [any ContractMember] = [backdrop, shape, stroke, lineWidth]
}
