// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What hears the links its window is given: a link opened into the application - one chosen elsewhere, its scheme
/// the application's - goes to the window it names, else the one the user came to last, and every page and
/// arrangement there that hears links takes it.
public enum OpenedLinkElementContract: Tier {
    /// The tier's name.
    public static let name = "OpenedLinkElement"

    /// A link was opened into the application and given to the window this page or arrangement stands in: its
    /// address.
    public static let linkOpened = ElementEvent<Self, String>("linkOpened", layer: .adaptive)

    /// The tier's own members.
    public static let members: [any ContractMember] = [linkOpened]
}
