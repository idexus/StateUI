// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A single view with an outline around it.
public enum BorderContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "Border"

    /// Every base host presents it with its native control.
    public static let layer: ElementLayer = .native

    /// A border is a view, padded around what it holds.
    public static let tiers: [any Contract.Type] = [ViewContract.self, PaddingElementContract.self]

    /// The shape the outline follows, and the shape the border's own background
    /// is painted to.
    public static let shape = ElementProperty<Self, BorderShape>("shape", layer: .stateUI)

    /// What the outline is painted with - any brush, a gradient included.
    public static let stroke = ElementProperty<Self, Brush>("stroke", layer: .stateUI)

    /// How far into the dash pattern the outline starts.
    public static let strokeDashOffset = ElementProperty<Self, Double>("strokeDashOffset", layer: .stateUI)

    /// The dashes and the gaps between them, in multiples of the stroke width.
    public static let strokeDashPattern = ElementProperty<Self, [Double]>(
        "strokeDashPattern", layer: .stateUI, travels: false)

    /// How the ends of each dash are drawn.
    public static let strokeLineCap = ElementProperty<Self, LineCap>("strokeLineCap", layer: .stateUI)

    /// How the outline turns a corner.
    public static let strokeLineJoin = ElementProperty<Self, LineJoin>("strokeLineJoin", layer: .stateUI)

    /// How far a sharp corner may reach before it is cut off, in multiples of
    /// the stroke width.
    public static let strokeMiterLimit = ElementProperty<Self, Double>("strokeMiterLimit", layer: .stateUI)

    /// How wide the outline is drawn, in device units.
    public static let strokeWidth = ElementProperty<Self, Double>(
        "strokeWidth", layer: .stateUI, moves: .size)

    /// The element's own members.
    public static let members: [any ContractMember] = [
        shape, stroke, strokeDashOffset, strokeDashPattern, strokeLineCap, strokeLineJoin, strokeMiterLimit,
        strokeWidth,
    ]
}
