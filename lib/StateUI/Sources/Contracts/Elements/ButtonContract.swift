// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A button with a caption, and a handler for the press.
public enum ButtonContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "Button"

    /// Every base host presents it with its native control.
    public static let layer: ElementLayer = .native

    /// A button is a view with a caption in a font, padded, bordered, with a
    /// picture fitted.
    public static let tiers: [any Contract.Type] = [
        ViewContract.self, TextElementContract.self, FontElementContract.self, PaddingElementContract.self,
        BorderElementContract.self, ImageElementContract.self,
    ]

    /// The button was pressed and released on it.
    public static let clicked = ElementEvent<Self, Void>("clicked", layer: .native)

    /// The picture beside the caption.
    public static let icon = ElementProperty<Self, ImageSource>("icon", layer: .adaptive)

    /// Which side of the caption the icon stands on.
    public static let iconPosition = ElementProperty<Self, IconPosition>("iconPosition", layer: .adaptive)

    /// The gap between the icon and the caption, in device units.
    public static let iconSpacing = ElementProperty<Self, Double>("iconSpacing", layer: .adaptive)

    /// What happens to a caption too long for the button.
    public static let lineBreak = ElementProperty<Self, LineBreak>("lineBreak", layer: .native)

    /// A finger went down on the button.
    public static let pressed = ElementEvent<Self, Void>("pressed", layer: .native)

    /// The finger was lifted, wherever it ended up.
    public static let released = ElementEvent<Self, Void>("released", layer: .native)

    /// The element's own members.
    public static let members: [any ContractMember] = [
        clicked, icon, iconPosition, iconSpacing, lineBreak, pressed, released,
    ]
}
