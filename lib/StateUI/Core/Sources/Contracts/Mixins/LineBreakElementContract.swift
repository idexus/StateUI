// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What happens to words too long for their room: they wrap, or they are cut and say so - a text's, a button's caption.
public enum LineBreakElementContract: Tier {
    /// The tier's own name.
    public static let name = "LineBreakElement"

    /// What happens to text too long for the space: it wraps, or it is cut and
    /// says so.
    public static let lineBreak = ElementProperty<Self, LineBreak>("lineBreak", layer: .native)

    /// The tier's own members.
    public static let members: [any ContractMember] = [lineBreak]
}
