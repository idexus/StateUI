// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A view shown above a window's page, over everything else it holds.
public enum OverlayContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = .overlay

    /// It carries structure, not a platform control of its own.
    public static let layer: ElementLayer = .structure

    /// The element's own members.
    public static let members: [any ContractMember] = []
}
