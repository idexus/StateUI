// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The menu a view offers where the reader asks for one - a secondary click, a
/// long press.
public enum ContextMenuContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "ContextMenu"

    /// It carries structure, not a platform control of its own.
    public static let layer: ElementLayer = .structure

    /// The element's own members.
    public static let members: [any ContractMember] = []
}
