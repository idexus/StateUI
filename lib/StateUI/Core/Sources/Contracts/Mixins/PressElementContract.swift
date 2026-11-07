// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a control held down and let go of reports: a button, a slider, a bar's button.
public enum PressElementContract: Tier {
    /// The tier's own name.
    public static let name = "PressElement"

    /// A press began on it: a finger, a pen or a mouse button went down.
    public static let pressed = ElementEvent<Self, Void>("pressed", layer: .native)

    /// The press ended, wherever the pointer ended up.
    public static let released = ElementEvent<Self, Void>("released", layer: .native)

    /// The tier's own members.
    public static let members: [any ContractMember] = [pressed, released]
}
