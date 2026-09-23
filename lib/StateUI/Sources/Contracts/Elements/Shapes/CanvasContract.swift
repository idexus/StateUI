// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A canvas to draw on, one instruction at a time.
public enum CanvasContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "Canvas"

    /// Every base host presents it with its native control.
    public static let layer: ElementLayer = .native

    /// A canvas is a view.
    public static let tiers: [any Contract.Type] = [ViewContract.self]

    /// A finger moved while down, to where it is now, in the canvas's
    /// coordinates.
    public static let dragged = ElementEvent<Self, Point>("dragged", layer: .native)

    /// What the canvas draws: its instructions, in order.
    public static let drawable = ElementProperty<Self, [DrawCommand]>("drawable", layer: .structure)

    /// A finger went down, or a mouse button was pressed, at a point in the
    /// canvas.
    public static let pressed = ElementEvent<Self, Point>("pressed", layer: .native)

    /// It was lifted, where it left off.
    public static let released = ElementEvent<Self, Point>("released", layer: .native)

    /// The element's own members.
    public static let members: [any ContractMember] = [dragged, drawable, pressed, released]
}
