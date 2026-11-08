// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The keyed style an element wears from the application's style sheet: a view's, a bar item's.
public enum StyledElementContract: Tier {
    /// The tier's own name.
    public static let name = "StyledElement"

    /// The keyed style the element wears, by its key.
    public static let style = ElementProperty<Self, Name>("style", layer: .structure)

    /// The tier's own members.
    public static let members: [any ContractMember] = [style]
}
