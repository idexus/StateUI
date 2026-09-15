// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A line between entries, grouping the ones above it apart from the ones
/// below.
public enum MenuSeparatorContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = .menuSeparator

    /// It carries structure, not a platform control of its own.
    public static let layer: ElementLayer = .structure

    /// The element's own members.
    public static let members: [any ContractMember] = []
}
