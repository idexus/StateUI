// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// How far apart the lines of text are.
public enum LineHeightElementContract: Contract {
    /// The tier's name.
    public static let name = "LineHeightElement"

    /// Line height is carried as a value in the tree.
    public static let tiers: [any Contract.Type] = [PropertyContainerContract.self]

    /// The height of one line, as a multiple of the font's own.
    public static let lineHeight = ElementProperty<Self, Double>("lineHeight", layer: .native, moves: .text)

    /// The tier's own members.
    public static let members: [any ContractMember] = [lineHeight]
}
