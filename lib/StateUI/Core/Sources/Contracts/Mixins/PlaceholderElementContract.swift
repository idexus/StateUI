// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The words an element shows while it holds nothing: a field while it is empty, a picker while nothing is chosen.
public enum PlaceholderElementContract: Tier {
    /// The tier's own name.
    public static let name = "PlaceholderElement"

    /// The words it shows while it holds nothing.
    public static let placeholder = ElementProperty<Self, String>("placeholder", layer: .native)

    /// The tier's own members.
    public static let members: [any ContractMember] = [placeholder]
}
