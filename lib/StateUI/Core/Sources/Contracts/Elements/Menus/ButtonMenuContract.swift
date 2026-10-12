// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The menu a button opens: its entries, shown under the button as a click asks - the whole button's click, or the
/// part of a split button its own action leaves.
public enum ButtonMenuContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "ButtonMenu"

    /// It carries structure, not a platform control of its own: the button opens the toolkit's own menu.
    public static let layer: ElementLayer = .structure

    /// The element's own members.
    public static let members: [any ContractMember] = []
}
