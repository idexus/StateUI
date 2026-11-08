// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A setting on the page's bar, standing on or off - a two-state button.
public enum ToolbarToggleContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "ToolbarToggle"

    /// It carries structure, not a platform control of its own.
    public static let layer: ElementLayer = .structure

    /// A setting on the bar is an item a user chooses; where its host draws the bar itself, its look is the
    /// application's to say.
    public static let tiers: [any Tier.Type] = [
        AutomationElementContract.self, EnabledElementContract.self, IconElementContract.self,
        ShortcutElementContract.self, TextElementContract.self, TextAndIconElementContract.self,
        HoverElementContract.self, BackgroundElementContract.self, StyledElementContract.self,
        BorderElementContract.self, TextColorElementContract.self, FontElementContract.self,
        PaddingElementContract.self, ToggleElementContract.self, PressElementContract.self,
    ]

    /// The picture it shows while on, in place of its own; unwritten, its own picture both ways.
    public static let onIcon = ElementProperty<Self, ImageSource>("onIcon", layer: .adaptive)

    /// The element's own members.
    public static let members: [any ContractMember] = [onIcon]
}
