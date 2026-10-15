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

    /// Where the run rests or is going: the element wears the layout's phase, so the host walks it under the
    /// layout's motion and says where it stands every frame.
    public static let phase = ElementProperty<Self, Double>("phase", layer: .stateUI)

    /// The element's own members.
    public static let members: [any ContractMember] = [phase]
}
