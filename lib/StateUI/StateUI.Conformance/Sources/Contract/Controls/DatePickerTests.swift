// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `DatePickerContract` on a host: the user's day heard once and landing on the state, the program's shown and heard by
/// nobody; the calendar the user opens and closes heard, the one the program opens not; a day not in the calendar
/// leaving the day shown and one past the range standing at its end; the range and the way the day is written.
@_spi(Host) public enum DatePickerTests: ConformanceFamily {
    public static let name = "DatePicker"

    public static var cases: [ConformanceCase] {
        [
            Aspects.standsAlone("DatePicker"),
            ConformanceCase("theUsersDayIsHeardAndTheProgramsIsNot", proves: [
                Covered(DatePickerContract.date), Covered(DatePickerContract.dateChanged),
            ], needs: [Covered(ClickElementContract.clicked, on: ButtonContract.self)]) { s in
                let due = State(wrappedValue: CalendarDate(year: 2026, month: 9, day: 25))
                let heard = Received<CalendarDate>()
                s.start {
                    VStack {
                        DatePicker(due.projectedValue).onDateChanged { heard.values.append($0) }.id("picker")
                        Button("New Year").onClicked { due.wrappedValue = CalendarDate(year: 2027, month: 1, day: 1) }
                            .id("change")
                    }
                }
                let picker = try s.element("picker")
                s.expect(try s.held(DatePickerContract.date, on: picker), CalendarDate(year: 2026, month: 9, day: 25))

                try s.perform(.pickDate(CalendarDate(year: 2026, month: 10, day: 3)), on: picker)
                s.settle { !heard.values.isEmpty }
                s.expect(heard.values, [CalendarDate(year: 2026, month: 10, day: 3)], "heard once")
                s.expect(due.wrappedValue, CalendarDate(year: 2026, month: 10, day: 3), "and on the state")

                try s.perform(.activate, on: s.element("change"))
                try s.settle { try s.held(DatePickerContract.date, on: picker) == CalendarDate(year: 2027, month: 1, day: 1) }
                s.expect(try s.held(DatePickerContract.date, on: picker), CalendarDate(year: 2027, month: 1, day: 1))
                s.expect(heard.values.count, 1, "the program's day heard by nobody")
            },
            ConformanceCase("aDayOutsideTheCalendarOrTheRangeIsHeldByTheRule", proves: [
                Covered(DatePickerContract.date),
            ], needs: [Covered(DatePickerContract.maximum), Covered(ClickElementContract.clicked, on: ButtonContract.self)]) { s in
                let due = State(wrappedValue: CalendarDate(year: 2026, month: 2, day: 10))
                s.start {
                    VStack {
                        DatePicker(due.projectedValue).maximum(CalendarDate(year: 2026, month: 6, day: 30))
                            .id("picker")
                        Button("No such day").onClicked { due.wrappedValue = CalendarDate(year: 2026, month: 2, day: 31) }
                            .id("impossible")
                        Button("Christmas").onClicked { due.wrappedValue = CalendarDate(year: 2026, month: 12, day: 24) }
                            .id("late")
                    }
                }
                let picker = try s.element("picker")

                try s.perform(.activate, on: s.element("impossible"))
                s.settle { due.wrappedValue == CalendarDate(year: 2026, month: 2, day: 31) }
                for _ in 0..<5 { s.turn() }
                s.expect(
                    try s.held(DatePickerContract.date, on: picker), CalendarDate(year: 2026, month: 2, day: 10),
                    "a day not in the calendar leaves the day shown")

                try s.perform(.activate, on: s.element("late"))
                try s.settle {
                    try s.held(DatePickerContract.date, on: picker) != CalendarDate(year: 2026, month: 2, day: 10)
                }
                s.expect(
                    try s.held(DatePickerContract.date, on: picker), CalendarDate(year: 2026, month: 6, day: 30),
                    "a day past the range stands at its end")
            },
            Aspects.holds(
                DatePickerContract.minimum, on: "DatePicker", CalendarDate(year: 2026, month: 1, day: 1),
                then: CalendarDate(year: 2026, month: 6, day: 1),
                with: [Write(DatePickerContract.date, CalendarDate(year: 2026, month: 9, day: 25))]),
            Aspects.holds(
                DatePickerContract.maximum, on: "DatePicker", CalendarDate(year: 2026, month: 12, day: 31),
                then: CalendarDate(year: 2026, month: 10, day: 1),
                with: [Write(DatePickerContract.date, CalendarDate(year: 2026, month: 9, day: 25))]),
            Aspects.holds(DatePickerContract.format, on: "DatePicker", DateFormat.long, then: .short,
                          with: [Write(DatePickerContract.date, CalendarDate(year: 2026, month: 9, day: 25))]),
        ]
    }
}
