// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a page shows about itself - a title and a picture where another
/// container presents it as an item, and what it stands on - and the links its
/// window is given. A page and an arrangement say them under the same keys, so
/// both wear this tier, and it wears nothing: an arrangement's background is the
/// ground of its pages that say none.
public enum PageElementContract: Contract {
    /// The tier's name.
    public static let name = "PageElement"

    /// What the page stands on behind what it shows; on an arrangement, what each of its pages that says none
    /// stands on.
    public static let background = ElementProperty<Self, Material>("background", layer: .adaptive)

    /// The application was asked to open a link - one chosen elsewhere, its scheme the application's - and gave it
    /// to the window this page or arrangement stands in: its address.
    public static let linkOpened = ElementEvent<Self, String>("linkOpened", layer: .adaptive)

    /// The picture shown with the title - a tab's icon.
    public static let icon = ElementProperty<Self, ImageSource>("icon", layer: .adaptive)

    /// The title.
    public static let title = ElementProperty<Self, String>("title", layer: .native)

    /// The tier's own members.
    public static let members: [any ContractMember] = [background, icon, linkOpened, title]
}
