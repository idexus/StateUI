// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The color of text, wherever it is drawn.
public enum TextColorElementContract: Contract {
    /// The tier's name.
    public static let name = "TextColorElement"

    /// The color the text is drawn in.
    public static let textColor = ElementProperty<Self, Color>("textColor", layer: .native)

    /// The tier's own members.
    public static let members: [any ContractMember] = [textColor]
}
