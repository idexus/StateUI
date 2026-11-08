// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `PopupElementContract` on a host, on each element wearing the tier, in the place it stands.
@_spi(Host) public enum PopupElementTests: ConformanceFamily {
    public static let name = "PopupElement"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("DatePicker.theCalendarTheUserOpensAndClosesIsHeard", proves: [
                Covered(PopupElementContract.isOpen, on: DatePickerContract.self), Covered(PopupElementContract.opened, on: DatePickerContract.self), Covered(PopupElementContract.closed, on: DatePickerContract.self),
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
                s.expect(try s.held(PopupElementContract.isOpen, on: picker), true)
                try s.perform(.close, on: picker)
                s.settle { heard.values.count == 2 }

                s.expect(heard.values, ["opened", "closed"])
                s.expect(try s.held(PopupElementContract.isOpen, on: picker), false)
            },
            ConformanceCase("DatePicker.theCalendarTheProgramOpensIsHeardOnlyAsTheUserClosesIt", proves: [
                Covered(PopupElementContract.isOpen, on: DatePickerContract.self), Covered(PopupElementContract.closed, on: DatePickerContract.self),
            ], needs: [Covered(ClickElementContract.clicked, on: ButtonContract.self)]) { s in
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
                try s.settle { try s.held(PopupElementContract.isOpen, on: picker) == true }
                s.expect(try s.held(PopupElementContract.isOpen, on: picker), true)
                s.turn()
                s.expect(heard.values, [], "the program's opening heard by nobody")

                try s.perform(.close, on: picker)
                s.settle { heard.values == ["closed"] }
                s.expect(heard.values, ["closed"], "the user closing what the program opened")
            },
            ConformanceCase("Picker.theListTheUserOpensAndClosesIsHeard", proves: [
                Covered(PopupElementContract.isOpen, on: PickerContract.self), Covered(PopupElementContract.opened, on: PickerContract.self), Covered(PopupElementContract.closed, on: PickerContract.self),
            ]) { s in
                let heard = Received<String>()
                let size = State<String?>(wrappedValue: nil)
                s.start {
                    VStack {
                        Picker(["S", "M", "L"], selection: size.projectedValue)
                            .onOpened { heard.values.append("opened") }
                            .onClosed { heard.values.append("closed") }
                            .id("picker")
                    }
                }
                let picker = try s.element("picker")

                try s.perform(.open, on: picker)
                s.settle { heard.values == ["opened"] }
                s.expect(try s.held(PopupElementContract.isOpen, on: picker), true)
                try s.perform(.close, on: picker)
                s.settle { heard.values.count == 2 }

                s.expect(heard.values, ["opened", "closed"])
                s.expect(try s.held(PopupElementContract.isOpen, on: picker), false)
            },
            ConformanceCase("Picker.theListTheProgramOpensIsHeardOnlyAsTheUserClosesIt", proves: [
                Covered(PopupElementContract.isOpen, on: PickerContract.self), Covered(PopupElementContract.closed, on: PickerContract.self),
            ], needs: [Covered(ClickElementContract.clicked, on: ButtonContract.self)]) { s in
                let showing = State(wrappedValue: false)
                let heard = Received<String>()
                let size = State<String?>(wrappedValue: nil)
                s.start {
                    VStack {
                        Picker(["S", "M", "L"], selection: size.projectedValue)
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
                try s.settle { try s.held(PopupElementContract.isOpen, on: picker) == true }
                s.turn()
                s.expect(heard.values, [], "the program's opening heard by nobody")

                try s.perform(.close, on: picker)
                s.settle { heard.values == ["closed"] }
                s.expect(heard.values, ["closed"], "the user closing what the program opened")
            },
            ConformanceCase("TimePicker.theClockTheUserOpensAndClosesIsHeard", proves: [
                Covered(PopupElementContract.isOpen, on: TimePickerContract.self), Covered(PopupElementContract.opened, on: TimePickerContract.self), Covered(PopupElementContract.closed, on: TimePickerContract.self),
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
                s.expect(try s.held(PopupElementContract.isOpen, on: picker), true)
                try s.perform(.close, on: picker)
                s.settle { heard.values.count == 2 }

                s.expect(heard.values, ["opened", "closed"])
                s.expect(try s.held(PopupElementContract.isOpen, on: picker), false)
            },
            ConformanceCase("TimePicker.theClockTheProgramOpensIsHeardOnlyAsTheUserClosesIt", proves: [
                Covered(PopupElementContract.isOpen, on: TimePickerContract.self), Covered(PopupElementContract.closed, on: TimePickerContract.self),
            ], needs: [Covered(ClickElementContract.clicked, on: ButtonContract.self)]) { s in
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
                try s.settle { try s.held(PopupElementContract.isOpen, on: picker) == true }
                s.turn()
                s.expect(heard.values, [], "the program's opening heard by nobody")

                try s.perform(.close, on: picker)
                s.settle { heard.values == ["closed"] }
                s.expect(heard.values, ["closed"], "the user closing what the program opened")
            },
        ]
    }
}
