// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What an element showing words and a picture has - a button, a bar's item: whether its words stand beside its
/// picture.
public enum TextAndIconElementContract: Contract {
    /// The tier's name.
    public static let name = "TextAndIconElement"

    /// Whether its words stand beside its picture; left out, they still name it to assistive technology. An element
    /// with no picture shows its words whatever this says.
    public static let showsText = ElementProperty<Self, Bool>("showsText", layer: .adaptive)

    /// The tier's own members.
    public static let members: [any ContractMember] = [showsText]
}
