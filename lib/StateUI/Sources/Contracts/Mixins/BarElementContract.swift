// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The bar a page arrangement draws: its colour.
public enum BarElementContract: Contract {
    /// The tier's name.
    public static let name = "BarElement"

    /// The bar's colour is carried as a value in the tree.
    public static let tiers: [any Contract.Type] = [PropertyContainerContract.self]

    /// The bar's colour; unwritten, the platform's own material.
    public static let barBackgroundColor = ElementProperty<Self, Color>("barBackgroundColor", layer: .adaptive)

    /// The tier's own members.
    public static let members: [any ContractMember] = [barBackgroundColor]
}
