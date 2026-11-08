// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// How what an element draws fills the room it was given: a picture, a shape.
public enum ContentModeElementContract: Tier {
    /// The tier's name.
    public static let name = "ContentModeElement"

    /// How the drawing fills its room when the two are not the same shape.
    public static let contentMode = ElementProperty<Self, ContentMode>("contentMode", layer: .native)

    /// The tier's own members.
    public static let members: [any ContractMember] = [contentMode]
}
