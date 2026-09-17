// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The spinner shown while something is happening that has no measurable
/// length.
public enum ActivityIndicatorContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "ActivityIndicator"

    /// Every base host presents it with its native control.
    public static let layer: ElementLayer = .native

    /// A spinner is a view, tinted.
    public static let tiers: [any Contract.Type] = [ViewContract.self, TintElementContract.self]

    /// Whether it is spinning.
    public static let isRunning = ElementProperty<Self, Bool>("isRunning", layer: .native)

    /// The element's own members.
    public static let members: [any ContractMember] = [isRunning]
}
