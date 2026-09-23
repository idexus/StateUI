// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What every item a user chooses from has - a menu's entry, a toolbar's
/// item, a swipe's action: a caption, a picture, and something to run.
public enum MenuItemElementContract: Contract {
    /// The tier's name.
    public static let name = "MenuItemElement"

    /// An item carries values in the tree.
    public static let tiers: [any Contract.Type] = [PropertyContainerContract.self]

    /// The item was chosen.
    public static let clicked = ElementEvent<Self, Void>("clicked", layer: .native)

    /// The picture shown with the caption.
    public static let icon = ElementProperty<Self, ImageSource>("icon", layer: .adaptive)

    /// Whether choosing the item destroys something, which the platform marks.
    public static let isDestructive = ElementProperty<Self, Bool>("isDestructive", layer: .adaptive)

    /// Whether the item can be chosen.
    public static let isEnabled = ElementProperty<Self, Bool>("isEnabled", layer: .native)

    /// The caption.
    public static let text = ElementProperty<Self, String>("text", layer: .native)

    /// The tier's own members.
    public static let members: [any ContractMember] = [clicked, icon, isDestructive, isEnabled, text]
}
