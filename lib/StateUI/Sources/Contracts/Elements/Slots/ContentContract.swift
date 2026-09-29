// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The slot holding the view a container shows in its central place - a title
/// bar's middle.
public enum ContentContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "Content"

    /// It carries structure, not a platform control of its own.
    public static let layer: ElementLayer = .structure

    /// The element's own members.
    public static let members: [any ContractMember] = []
}
