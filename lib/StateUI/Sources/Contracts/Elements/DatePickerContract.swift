// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A day, chosen from the platform's own calendar.
public enum DatePickerContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = .datePicker

    /// Every base host presents it with its native control.
    public static let layer: ElementLayer = .native

    /// A date picker is a view whose text has a colour, a spacing and a font.
    public static let tiers: [any Contract.Type] = [
        ViewContract.self, TextStyleElementContract.self, FontElementContract.self,
    ]

    /// The calendar has closed - by a choice, a tap outside, or the platform.
    public static let closed = ElementEvent<Self, Void>("closed", layer: .native)

    /// The day the field shows.
    public static let date = ElementProperty<Self, CalendarDate>("date", layer: .native)

    /// A day was chosen.
    public static let dateChanged = ElementEvent<Self, CalendarDate>("dateChanged", layer: .native)

    /// How the day is written in the field, as a format string.
    public static let format = ElementProperty<Self, String>("format", layer: .native)

    /// Whether the calendar is showing.
    public static let isOpen = ElementProperty<Self, Bool>("isOpen", layer: .native)

    /// The latest day the calendar offers.
    public static let maximumDate = ElementProperty<Self, CalendarDate>("maximumDate", layer: .native)

    /// The earliest day the calendar offers.
    public static let minimumDate = ElementProperty<Self, CalendarDate>("minimumDate", layer: .native)

    /// The calendar has opened.
    public static let opened = ElementEvent<Self, Void>("opened", layer: .native)

    /// The element's own members.
    public static let members: [any ContractMember] = [
        closed, date, dateChanged, format, isOpen, maximumDate, minimumDate, opened,
    ]
}
