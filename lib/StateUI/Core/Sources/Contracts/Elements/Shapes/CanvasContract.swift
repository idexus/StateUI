// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A canvas to draw on, one instruction at a time.
public enum CanvasContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "Canvas"

    /// Every base host presents it with its native control.
    public static let layer: ElementLayer = .native

    /// A canvas is a view.
    public static let tiers: [any Tier.Type] = [ViewContract.self]

    /// What the canvas draws: its instructions, in order.
    public static let drawing = ElementProperty<Self, [DrawCommand]>("drawing", layer: .structure)

    /// The element's own members.
    public static let members: [any ContractMember] = [drawing]
}
