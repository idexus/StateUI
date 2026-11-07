// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A day, chosen from the platform's own calendar.
public enum DatePickerContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "DatePicker"

    /// Every base host presents it with its native control.
    public static let layer: ElementLayer = .native

    /// A date picker is a view whose text has a color, a spacing and a font.
    public static let tiers: [any Tier.Type] = [
        ViewContract.self, TextColorElementContract.self, FontElementContract.self, FocusElementContract.self,
        PopupElementContract.self,
    ]

    /// The day the field shows.
    public static let date = ElementProperty<Self, CalendarDate>("date", layer: .native)

    /// A day was chosen.
    public static let dateChanged = ElementEvent<Self, CalendarDate>("dateChanged", layer: .native)

    /// How much of the day is written out in the field, in the user's language.
    public static let format = ElementProperty<Self, DateFormat>("format", layer: .native)

    /// The latest day the calendar offers.
    public static let maximum = ElementProperty<Self, CalendarDate>("maximum", layer: .native, travels: false)

    /// The earliest day the calendar offers.
    public static let minimum = ElementProperty<Self, CalendarDate>("minimum", layer: .native, travels: false)

    /// The element's own members.
    public static let members: [any ContractMember] = [date, dateChanged, format, maximum, minimum]
}
