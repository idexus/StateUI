// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The pages presented over a window, the last of them on top.
public enum ModalStackContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "ModalStack"

    /// It carries structure, not a platform control of its own.
    public static let layer: ElementLayer = .structure

    /// The element's own members.
    public static let members: [any ContractMember] = []
}
