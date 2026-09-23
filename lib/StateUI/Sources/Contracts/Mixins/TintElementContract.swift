// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A control's one accent colour.
public enum TintElementContract: Contract {
    /// The tier's name.
    public static let name = "TintElement"

    /// The accent is carried as a value in the tree.
    public static let tiers: [any Contract.Type] = [PropertyContainerContract.self]

    /// The colour the control's own marks are drawn in - a switch's track, a
    /// slider's filled part, a spinner.
    public static let tint = ElementProperty<Self, Color>("tint", layer: .adaptive)

    /// The tier's own members.
    public static let members: [any ContractMember] = [tint]
}
