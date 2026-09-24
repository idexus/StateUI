// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What an element draws of its own box: the shape its background, its outline and its cut follow, and the
/// outline.
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

    /// The shape the element's background, its outline and - where it clips - what it holds follow.
    public static let shape = ElementProperty<Self, BorderShape>("shape", layer: .stateUI)

    /// What the outline is painted with.
    public static let stroke = ElementProperty<Self, Brush>("stroke", layer: .stateUI)

    /// How wide the outline is drawn, in device units.
    public static let strokeWidth = ElementProperty<Self, Double>("strokeWidth", layer: .stateUI, moves: .size)

    /// The tier's own members.
    public static let members: [any ContractMember] = [
        borderColor, borderWidth, cornerRadius, shape, stroke, strokeWidth,
    ]
}
