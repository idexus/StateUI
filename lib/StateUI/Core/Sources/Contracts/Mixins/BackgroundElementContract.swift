// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What an element is painted on: a view's, a page's, a window's, a bar item's and a run of text's background.
public enum BackgroundElementContract: Tier {
    /// The tier's own name.
    public static let name = "BackgroundElement"

    /// What it is painted on: a color, a gradient, or a blur or glass what is
    /// behind shows through.
    public static let background = ElementProperty<Self, Material>("background", layer: .adaptive)

    /// The tier's own members.
    public static let members: [any ContractMember] = [background]
}
