// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What anything carrying values in the tree has - a control, a `Style`, a
/// text run: the name automation finds it by.
public enum PropertyContainerContract: Contract {
    /// The tier's name.
    public static let name = "PropertyContainer"

    /// A stable name automation finds the element by. Nothing shows it and no
    /// screen reader says it.
    public static let accessibilityIdentifier = ElementProperty<Self, String>(
        "accessibilityIdentifier", layer: .native)

    /// The tier's own members.
    public static let members: [any ContractMember] = [accessibilityIdentifier]
}
