// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What an item standing on a bar - a button, a setting or a group of them - shows of its own where its host draws
/// the bar itself: the keyed style it wears, what its surface is made of, and the pointer over it its visual states
/// follow. A host whose bar is the platform's keeps the platform's look.
public enum BarItemElementContract: Tier {
    /// The tier's name.
    public static let name = "BarItemElement"

    /// The keyed style the item wears, by its key.
    public static let style = ElementProperty<Self, Name>("style", layer: .structure)

    /// What the item's surface is made of: a color, a gradient, a blur of what lies behind it, or the platform's
    /// glass.
    public static let background = ElementProperty<Self, Material>("background", layer: .adaptive)

    /// The tiers it wears.
    public static let tiers: [any Tier.Type] = [HoverElementContract.self]

    /// The tier's own members.
    public static let members: [any ContractMember] = [style, background]
}
