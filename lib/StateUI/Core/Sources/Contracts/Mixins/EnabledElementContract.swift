// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Whether the user's hand reaches an element: a view, a menu, an entry in one, a toolbar's group.
public enum EnabledElementContract: Tier {
    /// The tier's own name.
    public static let name = "EnabledElement"

    /// Whether the user's hand reaches it: one disabled shows so and takes no input.
    public static let isEnabled = ElementProperty<Self, Bool>("isEnabled", layer: .native)

    /// The tier's own members.
    public static let members: [any ContractMember] = [isEnabled]
}
