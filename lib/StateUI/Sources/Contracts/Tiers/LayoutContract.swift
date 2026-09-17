// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What every layout has: the screen's unsafe strips it keeps clear of, and
/// whether its children are clipped or let input through.
public enum LayoutContract: Contract {
    /// The tier's name.
    public static let name = "Layout"

    /// A layout is a view, and keeps space inside itself.
    public static let tiers: [any Contract.Type] = [ViewContract.self, PaddingElementContract.self]

    /// What each edge of the layout stays clear of on the screen's unsafe
    /// strip.
    public static let avoidsSafeArea = ElementProperty<Self, SafeAreaEdges>(
        "avoidsSafeArea", layer: .adaptive)

    /// Whether children are cut off at the layout's edges.
    public static let clipsContent = ElementProperty<Self, Bool>("clipsContent", layer: .native)

    /// Whether input on the layout's own empty space passes to what is under
    /// it.
    public static let letsInputThrough = ElementProperty<Self, Bool>("letsInputThrough", layer: .native)

    /// The tier's own members.
    public static let members: [any ContractMember] = [avoidsSafeArea, clipsContent, letsInputThrough]
}
