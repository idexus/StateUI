// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The view a page stands at its foot, its safe area ending above it.
public enum BottomBarContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "BottomBar"

    /// Each host stands it as its platform's bars stand: over the page where they stand over it, else beside it.
    public static let layer: ElementLayer = .adaptive

    /// The element's own members.
    public static let members: [any ContractMember] = []
}
