// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Words on the page's bar that nobody chooses - how many items, what was last saved.
public enum ToolbarLabelContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "ToolbarLabel"

    /// It carries structure, not a platform control of its own.
    public static let layer: ElementLayer = .structure

    /// The words it shows.
    public static let text = ElementProperty<Self, String>("text", layer: .native)

    /// The picture before its words.
    public static let icon = ElementProperty<Self, ImageSource>("icon", layer: .adaptive)

    /// The element's own members.
    public static let members: [any ContractMember] = [icon, text]
}
