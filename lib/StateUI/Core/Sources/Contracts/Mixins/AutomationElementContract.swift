// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What an element the platform's automation meets has - a drawn element, a menu's entry or a bar's item, an
/// arrangement of pages: the name automation finds it by.
public enum AutomationElementContract: Contract {
    /// The tier's name.
    public static let name = "AutomationElement"

    /// A stable name automation finds the element by. Nothing shows it and no
    /// screen reader says it.
    public static let accessibilityIdentifier = ElementProperty<Self, String>(
        "accessibilityIdentifier", layer: .native)

    /// The tier's own members.
    public static let members: [any ContractMember] = [accessibilityIdentifier]
}
