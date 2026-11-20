// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Stands each of its views where a motion layout's arithmetic puts it, one over another - the element a
/// `MotionLayout` is.
public enum MotionLayoutContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "MotionLayout"

    /// StateUI decides its geometry, its arrangement or its composition; a host
    /// draws what was decided.
    public static let layer: ElementLayer = .stateUI

    /// It is a layout; where each child stands is the run of placements an engine writes.
    public static let tiers: [any Tier.Type] = [LayoutContract.self]

    /// Where the parameters rest or are going, one number an axis: the element wears the layout's parameters, so the
    /// host walks them under the layout's motion and says where they stand every frame.
    public static let parameters = ElementProperty<Self, [Double]>("parameters", layer: .stateUI)

    /// The hand holding one view by itself: its phase, where it is in the element, how fast it was going as it lets
    /// go, per second, how long it has stood still, in milliseconds, and which view - its place among the
    /// layout's views.
    public static let itemDragUpdated = ElementEvent<Self, (GesturePhase, Point, Point, Double, Int)>(
        "itemDragUpdated", layer: .native)

    /// The layout's arithmetic: the host says the room the element stands in, and reads where each child stands
    /// whenever the arithmetic was worked out again.
    public static let layout = ElementProgram<Self, LayoutProgramDefinition>("layout", layer: .stateUI)

    /// Whether the layout turns about its middle where it lays out right to left: its views' places, their move
    /// along and their turn, and the hand over it.
    public static let mirrorsRightToLeft = ElementProperty<Self, Bool>(
        "mirrorsRightToLeft", layer: .stateUI, travels: false)

    /// The element's own members.
    public static let members: [any ContractMember] = [
        itemDragUpdated, layout, mirrorsRightToLeft, parameters,
    ]
}
