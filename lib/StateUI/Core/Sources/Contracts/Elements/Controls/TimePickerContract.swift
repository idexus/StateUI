// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A time of day, chosen from the platform's own clock.
public enum TimePickerContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "TimePicker"

    /// Every base host presents it with its native control.
    public static let layer: ElementLayer = .native

    /// A time picker is a view whose text has a color, a spacing and a font.
    public static let tiers: [any Tier.Type] = [
        ViewContract.self, TextColorElementContract.self, FontElementContract.self, FocusElementContract.self,
        PopupElementContract.self,
    ]

    /// How much of the time is written out.
    public static let format = ElementProperty<Self, TimeFormat>("format", layer: .native)

    /// The time the field shows, on a 24-hour clock.
    public static let time = ElementProperty<Self, ClockTime>("time", layer: .native)

    /// A time was chosen.
    public static let timeChanged = ElementEvent<Self, ClockTime>("timeChanged", layer: .native)

    /// The element's own members.
    public static let members: [any ContractMember] = [format, time, timeChanged]
}
