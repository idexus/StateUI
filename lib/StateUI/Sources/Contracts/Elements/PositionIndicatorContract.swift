// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The row of dots under a run of cards, saying how many there are and which
/// one is showing.
public enum PositionIndicatorContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "PositionIndicator"

    /// StateUI composes it from smaller primitives before a host receives the
    /// tree.
    public static let layer: ElementLayer = .stateUI

    /// A row of dots is a view.
    public static let tiers: [any Contract.Type] = [ViewContract.self]

    /// How many dots there are.
    public static let count = ElementProperty<Self, Int>("count", layer: .stateUI, travels: false)

    /// Whether one lonely dot is hidden rather than drawn.
    public static let hideSingle = ElementProperty<Self, Bool>("hideSingle", layer: .stateUI)

    /// The colour of a dot that is not the current one.
    public static let indicatorColor = ElementProperty<Self, Color>("indicatorColor", layer: .stateUI)

    /// How big each dot is, in device units.
    public static let indicatorSize = ElementProperty<Self, Double>("indicatorSize", layer: .stateUI)

    /// A dot or a square, for every dot.
    public static let indicatorsShape = ElementProperty<Self, IndicatorShape>(
        "indicatorsShape", layer: .stateUI)

    /// The most dots drawn, however many items there are.
    public static let maximumVisible = ElementProperty<Self, Int>(
        "maximumVisible", layer: .stateUI, travels: false)

    /// Which dot is the current one, counting from zero.
    public static let position = ElementProperty<Self, Int>("position", layer: .stateUI, travels: false)

    /// The colour of the current dot.
    public static let selectedIndicatorColor = ElementProperty<Self, Color>(
        "selectedIndicatorColor", layer: .stateUI)

    /// The element's own members.
    public static let members: [any ContractMember] = [
        count, hideSingle, indicatorColor, indicatorSize, indicatorsShape, maximumVisible, position,
        selectedIndicatorColor,
    ]
}
