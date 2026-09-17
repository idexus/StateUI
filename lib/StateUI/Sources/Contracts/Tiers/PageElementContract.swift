// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a page shows about itself where another container presents it as an
/// item - a title and a picture. A page and an arrangement say them under the
/// same keys, so both wear this tier, and it wears nothing: a page carries its
/// title and its icon, and no other value an element carries.
public enum PageElementContract: Contract {
    /// The tier's name.
    public static let name = "PageElement"

    /// The picture shown with the title - a tab's icon.
    public static let icon = ElementProperty<Self, ImageSource>("icon", layer: .adaptive)

    /// The title.
    public static let title = ElementProperty<Self, String>("title", layer: .native)

    /// The tier's own members.
    public static let members: [any ContractMember] = [icon, title]
}
