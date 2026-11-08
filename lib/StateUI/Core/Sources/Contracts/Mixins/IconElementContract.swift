// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The picture an element shows beside or for its words: a button's, a toolbar label's, a menu entry's, a page's.
public enum IconElementContract: Tier {
    /// The tier's own name.
    public static let name = "IconElement"

    /// The picture beside its words, or for them.
    public static let icon = ElementProperty<Self, ImageSource>("icon", layer: .adaptive)

    /// The tier's own members.
    public static let members: [any ContractMember] = [icon]
}
