// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What every drawn shape has: what fills it, the line around it, how it fits
/// its room, and a transform of its own drawing.
public enum ShapeContract: Contract {
    /// The tier's name.
    public static let name = "Shape"

    /// A shape is a view.
    public static let tiers: [any Contract.Type] = [ViewContract.self]

    /// How the shape fills the room it was given when the two differ.
    public static let aspect = ElementProperty<Self, Aspect>("aspect", layer: .native)

    /// What the inside of the shape is painted with.
    public static let fill = ElementProperty<Self, Brush>("fill", layer: .stateUI)

    /// A transform of the shape's drawing, which moves nothing around it.
    public static let renderTransform = ElementProperty<Self, ViewTransform>("renderTransform", layer: .native)

    /// What the outline is painted with.
    public static let stroke = ElementProperty<Self, Brush>("stroke", layer: .stateUI)

    /// How far into the dash pattern the outline starts.
    public static let strokeDashOffset = ElementProperty<Self, Double>("strokeDashOffset", layer: .stateUI)

    /// The outline's dashes and gaps, in turn, in stroke widths.
    public static let strokeDashPattern = ElementProperty<Self, [Double]>(
        "strokeDashPattern", layer: .stateUI, travels: false)

    /// How the ends of an open outline are drawn.
    public static let strokeLineCap = ElementProperty<Self, LineCap>("strokeLineCap", layer: .stateUI)

    /// How two segments of the outline meet.
    public static let strokeLineJoin = ElementProperty<Self, LineJoin>("strokeLineJoin", layer: .stateUI)

    /// How far out a sharp corner may reach before it is cut off.
    public static let strokeMiterLimit = ElementProperty<Self, Double>("strokeMiterLimit", layer: .stateUI)

    /// How thick the outline is.
    public static let strokeWidth = ElementProperty<Self, Double>(
        "strokeWidth", layer: .stateUI, moves: .size)

    /// The tier's own members.
    public static let members: [any ContractMember] = [
        aspect, fill, renderTransform, stroke, strokeDashOffset, strokeDashPattern,
        strokeLineCap, strokeLineJoin, strokeMiterLimit, strokeWidth,
    ]
}
