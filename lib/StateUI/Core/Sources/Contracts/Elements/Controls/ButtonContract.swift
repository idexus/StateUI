// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A button with a caption, and a handler for the press.
public enum ButtonContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "Button"

    /// Every base host presents it with its native control.
    public static let layer: ElementLayer = .native

    /// A button is a view with a caption in a font, padded, bordered, with a
    /// picture fitted, and a menu it may open.
    public static let tiers: [any Tier.Type] = [
        ViewContract.self, TextualElementContract.self, TrackingElementContract.self, FontElementContract.self,
        PaddingElementContract.self, BorderElementContract.self, ContentModeElementContract.self, FocusElementContract.self,
        ButtonMenuElementContract.self, TextAndIconElementContract.self,
        PressElementContract.self,
        ClickElementContract.self,
        IconElementContract.self,
        ShortcutElementContract.self,
        LineBreakElementContract.self,
    ]

    /// Which side of the caption the icon stands on.
    public static let iconPosition = ElementProperty<Self, IconPosition>("iconPosition", layer: .adaptive)

    /// The gap between the icon and the caption, in device units.
    public static let iconSpacing = ElementProperty<Self, Double>("iconSpacing", layer: .adaptive)

    /// What the button stands for in its window - its main action, the way out, or one destroying something - drawn
    /// as each platform draws it; Return presses the main action and Escape the way out.
    public static let role = ElementProperty<Self, ButtonRole>("role", layer: .adaptive)

    /// The element's own members.
    public static let members: [any ContractMember] = [iconPosition, iconSpacing, role]
}
