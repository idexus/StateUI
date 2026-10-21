// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// An element that can hold the keyboard - a control taking the focus, or a layout holding the view that does - and
/// so hear the keys it takes.
public enum KeyboardElementContract: Contract {
    /// The tier's name.
    public static let name = "KeyboardElement"

    /// A key the element takes (`keysTaken`) was pressed while it held the keyboard, or held the view that did -
    /// with the keys held with it.
    public static let keyPressed = ElementEvent<Self, (Key, KeyModifiers)>("keyPressed", layer: .native)

    /// The keys the element takes as they are pressed, in StateUI's order.
    public static let keysTaken = ElementProperty<Self, [Key]>("keysTaken", layer: .structure, travels: false)

    /// The tier's own members.
    public static let members: [any ContractMember] = [keyPressed, keysTaken]
}
