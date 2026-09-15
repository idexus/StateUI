// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The slot holding the view a container shows at its far end - a title bar's
/// trailing view.
public enum TrailingContentContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = .trailingContent

    /// It carries structure, not a platform control of its own.
    public static let layer: ElementLayer = .structure

    /// The element's own members.
    public static let members: [any ContractMember] = []
}
