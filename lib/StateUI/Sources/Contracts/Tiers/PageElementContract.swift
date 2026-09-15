// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a page arrangement shows about itself: a title and a picture.
public enum PageElementContract: Contract {
    /// The tier's name.
    public static let name = "PageElement"

    /// A page arrangement carries values in the tree.
    public static let tiers: [any Contract.Type] = [PropertyContainerContract.self]

    /// The picture shown with the title - a tab's icon.
    public static let icon = ElementProperty<Self, ImageSource>("icon", layer: .adaptive)

    /// The title.
    public static let title = ElementProperty<Self, String>("title", layer: .native)

    /// The tier's own members.
    public static let members: [any ContractMember] = [icon, title]
}
