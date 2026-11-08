// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The words an element shows: a control's caption, a text's or a field's words, a menu's caption and its
/// items', a bar's label.
public enum TextElementContract: Tier {
    /// The tier's own name.
    public static let name = "TextElement"

    /// The words it shows.
    public static let text = ElementProperty<Self, String>("text", layer: .native)

    /// The tier's own members.
    public static let members: [any ContractMember] = [text]
}
