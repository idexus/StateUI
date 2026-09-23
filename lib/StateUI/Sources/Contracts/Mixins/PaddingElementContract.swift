// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The space kept inside an element, around what it holds.
public enum PaddingElementContract: Contract {
    /// The tier's name.
    public static let name = "PaddingElement"

    /// Padding is kept inside a drawn element.
    public static let tiers: [any Contract.Type] = [VisualElementContract.self]

    /// The space inside the element, between its edges and what it holds.
    public static let padding = ElementProperty<Self, Insets>("padding", layer: .native, moves: .spacing)

    /// The tier's own members.
    public static let members: [any ContractMember] = [padding]
}
