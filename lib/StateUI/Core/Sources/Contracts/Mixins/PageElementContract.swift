// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a page shows about itself - a title and a picture where another
/// container presents it as an item, and what it stands on - and the links its
/// window is given. A page and an arrangement say them under the same keys, so
/// both wear this tier, and it wears nothing: an arrangement's background is the
/// ground of its pages that say none.
public enum PageElementContract: Tier {
    /// The tier's name.
    public static let name = "PageElement"

    /// A link was opened into the application - one chosen elsewhere, its scheme the application's - and given
    /// to the window this page or arrangement stands in: its address.
    public static let linkOpened = ElementEvent<Self, String>("linkOpened", layer: .adaptive)

    /// The title.
    public static let title = ElementProperty<Self, String>("title", layer: .native)

    /// The tiers it wears.
    public static let tiers: [any Tier.Type] = [BackgroundElementContract.self, IconElementContract.self]

    /// The tier's own members.
    public static let members: [any ContractMember] = [linkOpened, title]
}
