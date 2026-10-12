// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// How text looks wherever it is drawn: its colour.
public enum TextStyleElementContract: Contract {
    /// The tier's name.
    public static let name = "TextStyleElement"

    /// The colour the text is drawn in.
    public static let textColor = ElementProperty<Self, Color>("textColor", layer: .native)

    /// The tier's own members.
    public static let members: [any ContractMember] = [textColor]
}
