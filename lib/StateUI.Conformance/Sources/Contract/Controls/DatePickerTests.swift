// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `DatePickerContract` on a host: the user's day heard once and landing on the state, the program's shown and heard by
/// nobody; the calendar the user opens and closes heard, the one the program opens not; the range and the way the
/// day is written.
@_spi(Host) public enum DatePickerTests: ConformanceFamily {
    public static let name = "DatePicker"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("theUsersDayIsHeardAndTheProgramsIsNot", covers: [
                Covered(DatePickerContract.self), Covered(DatePickerContract.date), Covered(DatePickerContract.dateChanged),
                Covered(ButtonContract.clicked),
            ]) { s in
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
            ConformanceCase("theCalendarTheUserOpensAndClosesIsHeard", covers: [
                Covered(DatePickerContract.isOpen), Covered(DatePickerContract.opened), Covered(DatePickerContract.closed),
            ]) { s in
                let heard = Received<String>()
                s.start {
                    VStack {
                        DatePicker(CalendarDate(year: 2026, month: 9, day: 25))
                            .onOpened { heard.values.append("opened") }
                            .onClosed { heard.values.append("closed") }
                            .id("picker")
                    }
                }
                let picker = try s.element("picker")

                try s.perform(.open, on: picker)
                s.settle { heard.values == ["opened"] }
                s.expect(try s.held(DatePickerContract.isOpen, on: picker), true)
                try s.perform(.close, on: picker)
                s.settle { heard.values.count == 2 }

                s.expect(heard.values, ["opened", "closed"])
                s.expect(try s.held(DatePickerContract.isOpen, on: picker), false)
            },
            ConformanceCase("theCalendarTheProgramOpensIsHeardOnlyAsTheUserClosesIt", covers: [
                Covered(DatePickerContract.isOpen), Covered(DatePickerContract.closed), Covered(ButtonContract.clicked),
            ]) { s in
                let showing = State(wrappedValue: false)
                let heard = Received<String>()
                s.start {
                    VStack {
                        DatePicker(CalendarDate(year: 2026, month: 9, day: 25))
                            .isOpen(showing.wrappedValue)
                            .onOpened { heard.values.append("opened") }
                            .onClosed {
                                heard.values.append("closed")
                                showing.wrappedValue = false
                            }
                            .id("picker")
                        Button("Open").onClicked { showing.wrappedValue = true }.id("open")
                    }
                }
                let picker = try s.element("picker")

                try s.perform(.activate, on: s.element("open"))
                try s.settle { try s.held(DatePickerContract.isOpen, on: picker) == true }
                s.expect(try s.held(DatePickerContract.isOpen, on: picker), true)
                s.expect(heard.values, [], "the program's opening heard by nobody")

                try s.perform(.close, on: picker)
                s.settle { heard.values == ["closed"] }
                s.expect(heard.values, ["closed"], "the user closing what the program opened")
            },
            Aspects.holds(
                DatePickerContract.minimumDate, on: "DatePicker", CalendarDate(year: 2026, month: 1, day: 1),
                then: CalendarDate(year: 2026, month: 6, day: 1),
                with: [Write(DatePickerContract.date, CalendarDate(year: 2026, month: 9, day: 25))]),
            Aspects.holds(
                DatePickerContract.maximumDate, on: "DatePicker", CalendarDate(year: 2026, month: 12, day: 31),
                then: CalendarDate(year: 2026, month: 10, day: 1),
                with: [Write(DatePickerContract.date, CalendarDate(year: 2026, month: 9, day: 25))]),
            Aspects.holds(DatePickerContract.format, on: "DatePicker", "D", then: "d",
                          with: [Write(DatePickerContract.date, CalendarDate(year: 2026, month: 9, day: 25))]),
        ]
    }
}
