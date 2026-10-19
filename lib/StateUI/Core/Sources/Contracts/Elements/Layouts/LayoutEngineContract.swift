// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Stands each of its views where a layout engine's arithmetic puts it, one over another - the element a
/// `LayoutEngine` is.
public enum LayoutEngineContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "LayoutEngine"

    /// StateUI decides its geometry, its arrangement or its composition; a host
    /// draws what was decided.
    public static let layer: ElementLayer = .stateUI

    /// It is a layout; where each child stands is the run of placements an engine writes.
    public static let tiers: [any Contract.Type] = [LayoutContract.self]

    /// Where the run rests or is going, one number an axis: the element wears the layout's phase, so the host walks
    /// it under the layout's motion and says where it stands every frame.
    public static let phase = ElementProperty<Self, [Double]>("phase", layer: .stateUI)

    /// Which way the hand moves the run, where a hand does: the host hears a finger, a pointer, a trackpad and a
    /// wheel moving that way over the element, and leaves the other way to whatever holds it.
    public static let handAxis = ElementProperty<Self, LayoutInput.Axis>("handAxis", layer: .structure, travels: false)

    /// The hand moving over the element: its phase, how far it moved across and down since the last report, and -
    /// as it lets go - how fast it was going, per second.
    public static let handMoved = ElementEvent<Self, (GesturePhase, Point, Point)>("handMoved", layer: .native)

    /// A wheel's notches over the element, as many as it turned, across and down, the way they move what is under
    /// the hand: each a step of the run to the next target that way.
    public static let handStepped = ElementEvent<Self, Point>("handStepped", layer: .native)

    /// How the hand takes one view by itself rather than moving the run, where it does: the host layer gives the
    /// hand to the view under the press by it.
    public static let itemDrag = ElementProperty<Self, ItemDragStart>("itemDrag", layer: .structure, travels: false)

    /// The hand holding one view by itself: its phase, where it is in the element, how fast it was going as it lets
    /// go, per second, and how long it has stood still, in milliseconds.
    public static let itemMoved = ElementEvent<Self, (GesturePhase, Point, Point, Double)>("itemMoved", layer: .native)

    /// Whether the hand moves the run every way, a pan: the host hears it across and down alike, and claims every
    /// first move.
    public static let pans = ElementProperty<Self, Bool>("pans", layer: .structure, travels: false)

    /// Whether two fingers spreading move the run, where they do: the host hears a pinch over the element - on a
    /// touch screen, or a trackpad's.
    public static let magnifies = ElementProperty<Self, Bool>("magnifies", layer: .structure, travels: false)

    /// Whether two fingers turning move the run, where they do: the host hears a rotation over the element - on a
    /// touch screen, or a trackpad's.
    public static let rotates = ElementProperty<Self, Bool>("rotates", layer: .structure, travels: false)

    /// Two fingers over the element, a pinch and a rotation as one: its phase, how far they spread - a scale - and
    /// turned, in degrees clockwise, since the last report, and as they lift, how fast, per second: the scale's
    /// logarithm across, the degrees down.
    public static let pinchMoved = ElementEvent<Self, (GesturePhase, Double, Double, Point)>(
        "pinchMoved", layer: .native)

    /// The element's own members.
    public static let members: [any ContractMember] = [
        handAxis, handMoved, handStepped, itemDrag, itemMoved, magnifies, pans, phase, pinchMoved, rotates,
    ]
}
