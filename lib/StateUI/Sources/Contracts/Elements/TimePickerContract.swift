// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A time of day, chosen from the platform's own clock.
public enum TimePickerContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "TimePicker"

    /// Every base host presents it with its native control.
    public static let layer: ElementLayer = .native

    /// A time picker is a view whose text has a colour, a spacing and a font.
    public static let tiers: [any Contract.Type] = [
        ViewContract.self, TextStyleElementContract.self, FontElementContract.self,
    ]

    /// The clock face has closed.
    public static let closed = ElementEvent<Self, Void>("closed", layer: .native)

    /// How the time is written, as a format string.
    public static let format = ElementProperty<Self, String>("format", layer: .native)

    /// Whether the clock face is showing.
    public static let isOpen = ElementProperty<Self, Bool>("isOpen", layer: .native)

    /// The clock face has opened.
    public static let opened = ElementEvent<Self, Void>("opened", layer: .native)

    /// The time the field shows, on a 24-hour clock.
    public static let time = ElementProperty<Self, ClockTime>("time", layer: .native)

    /// A time was chosen.
    public static let timeChanged = ElementEvent<Self, ClockTime>("timeChanged", layer: .native)

    /// The element's own members.
    public static let members: [any ContractMember] = [closed, format, isOpen, opened, time, timeChanged]
}
