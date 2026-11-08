// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a scene and a window report of the user's attention: coming to the front, leaving it, going out of sight.
public enum SessionElementContract: Tier {
    /// The tier's own name.
    public static let name = "SessionElement"

    /// It came to the front.
    public static let activated = ElementEvent<Self, Void>("activated", layer: .adaptive)

    /// It is showing behind another.
    public static let deactivated = ElementEvent<Self, Void>("deactivated", layer: .adaptive)

    /// It went out of sight.
    public static let stopped = ElementEvent<Self, Void>("stopped", layer: .adaptive)

    /// The tier's own members.
    public static let members: [any ContractMember] = [activated, deactivated, stopped]
}
