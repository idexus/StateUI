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
            ], needs: [Covered(ButtonContract.clicked)]) { s in
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
            ], needs: [Covered(ButtonContract.clicked)]) { s in
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
            ConformanceCase("theClockTheUserOpensAndClosesIsHeard", proves: [
                Covered(TimePickerContract.isOpen), Covered(TimePickerContract.opened), Covered(TimePickerContract.closed),
            ]) { s in
                let heard = Received<String>()
                s.start {
                    VStack {
                        TimePicker(ClockTime(hour: 7, minute: 30))
                            .onOpened { heard.values.append("opened") }
                            .onClosed { heard.values.append("closed") }
                            .id("picker")
                    }
                }
                let picker = try s.element("picker")

                try s.perform(.open, on: picker)
                s.settle { heard.values == ["opened"] }
                s.expect(try s.held(TimePickerContract.isOpen, on: picker), true)
                try s.perform(.close, on: picker)
                s.settle { heard.values.count == 2 }

                s.expect(heard.values, ["opened", "closed"])
                s.expect(try s.held(TimePickerContract.isOpen, on: picker), false)
            },
            ConformanceCase("theClockTheProgramOpensIsHeardOnlyAsTheUserClosesIt", proves: [
                Covered(TimePickerContract.isOpen), Covered(TimePickerContract.closed),
            ], needs: [Covered(ButtonContract.clicked)]) { s in
                let showing = State(wrappedValue: false)
                let heard = Received<String>()
                s.start {
                    VStack {
                        TimePicker(ClockTime(hour: 7, minute: 30))
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
                try s.settle { try s.held(TimePickerContract.isOpen, on: picker) == true }
                s.expect(heard.values, [], "the program's opening heard by nobody")

                try s.perform(.close, on: picker)
                s.settle { heard.values == ["closed"] }
                s.expect(heard.values, ["closed"], "the user closing what the program opened")
            },
            Aspects.holds(TimePickerContract.format, on: "TimePicker", "HH:mm", then: "h:mm tt",
                          with: [Write(TimePickerContract.time, ClockTime(hour: 7, minute: 30))]),
        ]
    }
}
