// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What every layout has: the edges it runs under what stands over its page
/// on, and whether its children are clipped or let input through.
public enum LayoutContract: Contract {
    /// The tier's name.
    public static let name = "Layout"

    /// A layout is a view, and keeps space inside itself.
    public static let tiers: [any Contract.Type] = [
        ViewContract.self, PaddingElementContract.self, BorderElementContract.self, KeyboardElementContract.self,
    ]

    /// The edges the layout runs under what stands over its page on.
    public static let ignoresSafeArea = ElementProperty<Self, SafeAreaEdges>(
        "ignoresSafeArea", layer: .adaptive)

    /// Whether children are cut off at the layout's edges.
    public static let clipsContent = ElementProperty<Self, Bool>("clipsContent", layer: .native)

    /// Whether input on the layout's own empty space passes to what is under
    /// it.
    public static let letsInputThrough = ElementProperty<Self, Bool>("letsInputThrough", layer: .native)

    /// The tier's own members.
    public static let members: [any ContractMember] = [ignoresSafeArea, clipsContent, letsInputThrough]
}
