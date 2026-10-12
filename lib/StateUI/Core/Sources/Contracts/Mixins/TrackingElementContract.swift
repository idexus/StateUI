// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The space between the letters of words an element draws as written - a text, a button's caption, a run.
public enum TrackingElementContract: Contract {
    /// The tier's name.
    public static let name = "TrackingElement"

    /// The space between the letters.
    public static let tracking = ElementProperty<Self, Double>(
        "tracking", layer: .native, moves: .text)

    /// The tier's own members.
    public static let members: [any ContractMember] = [tracking]
}
