// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// How far along something is, from 0 to 1.
public enum ProgressBarContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = .progressBar

    /// Every base host presents it with its native control.
    public static let layer: ElementLayer = .native

    /// A progress bar is a view, tinted.
    public static let tiers: [any Contract.Type] = [ViewContract.self, TintElementContract.self]

    /// How far along, as a fraction from 0 to 1.
    public static let progress = ElementProperty<Self, Double>("progress", layer: .native)

    /// The element's own members.
    public static let members: [any ContractMember] = [progress]
}
