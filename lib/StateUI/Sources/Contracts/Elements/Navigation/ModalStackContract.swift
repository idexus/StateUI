// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// An arrangement presenting pages over the page it holds: its first child is
/// that page, the others the sheets over it, the last on top.
public enum ModalStackContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "ModalStack"

    /// It carries structure; each platform presents its sheets its own way.
    public static let layer: ElementLayer = .adaptive

    /// A sheet went without the tree saying so - the user dismissed it -
    /// leaving this many presented.
    public static let popped = ElementEvent<Self, Int>("popped", layer: .adaptive)

    /// The element's own members.
    public static let members: [any ContractMember] = [popped]
}
