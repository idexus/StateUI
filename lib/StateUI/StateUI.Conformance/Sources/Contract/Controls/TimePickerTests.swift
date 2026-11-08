// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `TimePickerContract` on a host: the user's time heard once and landing on the state, the program's shown and
/// heard by nobody; a time past the day added up from midnight; the clock the user opens and closes heard, the one
/// the program opens not; the way the time is written.
@_spi(Host) public enum TimePickerTests: ConformanceFamily {
    public static let name = "TimePicker"

    public static var cases: [ConformanceCase] {
        [
            Aspects.standsAlone("TimePicker"),
            ConformanceCase("theUsersTimeIsHeardAndTheProgramsIsNot", proves: [
                Covered(TimePickerContract.time), Covered(TimePickerContract.timeChanged),
            ], needs: [Covered(ClickElementContract.clicked, on: ButtonContract.self)]) { s in
                let alarm = State(wrappedValue: ClockTime(hour: 7, minute: 30))
                let heard = Received<ClockTime>()
                s.start {
                    VStack {
                        TimePicker(alarm.projectedValue).onTimeChanged { heard.values.append($0) }.id("picker")
                        Button("Midnight").onClicked { alarm.wrappedValue = ClockTime(hour: 0, minute: 0) }.id("change")
                    }
                }
                let picker = try s.element("picker")
                s.expect(try s.held(TimePickerContract.time, on: picker), ClockTime(hour: 7, minute: 30))

                try s.perform(.pickTime(ClockTime(hour: 8, minute: 15)), on: picker)
                s.settle { !heard.values.isEmpty }
                s.expect(heard.values, [ClockTime(hour: 8, minute: 15)], "heard once")
                s.expect(alarm.wrappedValue, ClockTime(hour: 8, minute: 15), "and on the state")

                try s.perform(.activate, on: s.element("change"))
                try s.settle { try s.held(TimePickerContract.time, on: picker) == ClockTime(hour: 0, minute: 0) }
                s.expect(try s.held(TimePickerContract.time, on: picker), ClockTime(hour: 0, minute: 0))
                s.expect(heard.values.count, 1, "the program's time heard by nobody")
            },
            ConformanceCase("aTimePastTheDayStandsInTheNext", proves: [
                Covered(TimePickerContract.time),
            ], needs: [Covered(ClickElementContract.clicked, on: ButtonContract.self)]) { s in
                let alarm = State(wrappedValue: ClockTime(hour: 9, minute: 0))
                s.start {
                    VStack {
                        TimePicker(alarm.projectedValue).id("picker")
                        Button("Late").onClicked { alarm.wrappedValue = ClockTime(hour: 25, minute: 30) }.id("late")
                    }
                }
                let picker = try s.element("picker")

                try s.perform(.activate, on: s.element("late"))
                try s.settle { try s.held(TimePickerContract.time, on: picker) != ClockTime(hour: 9, minute: 0) }
                s.expect(
                    try s.held(TimePickerContract.time, on: picker), ClockTime(hour: 1, minute: 30),
                    "added up from midnight")
            },
            Aspects.holds(TimePickerContract.format, on: "TimePicker", TimeFormat.short, then: .medium,
                          with: [Write(TimePickerContract.time, ClockTime(hour: 7, minute: 30))]),
        ]
    }
}
