// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A value picked by dragging a thumb along a native track.
public enum SliderContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "Slider"

    /// Every base host presents it with its native control.
    public static let layer: ElementLayer = .native

    /// A slider is a view, tinted.
    public static let tiers: [any Tier.Type] = [
        ViewContract.self, TintElementContract.self, FocusElementContract.self,
        PressElementContract.self,
        RangeElementContract.self,
    ]

    /// The element's own members.
    public static let members: [any ContractMember] = []
}
