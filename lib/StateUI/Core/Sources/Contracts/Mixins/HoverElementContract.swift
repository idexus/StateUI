// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What an element the pointer comes over and leaves reports: a view, an item on a bar.
public enum HoverElementContract: Tier {
    /// The tier's own name.
    public static let name = "HoverElement"

    /// A pointer came over it.
    public static let pointerEntered = ElementEvent<Self, Void>("pointerEntered", layer: .native)

    /// A pointer left it.
    public static let pointerExited = ElementEvent<Self, Void>("pointerExited", layer: .native)

    /// The tier's own members.
    public static let members: [any ContractMember] = [pointerEntered, pointerExited]
}
