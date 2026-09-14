import StateUI

/// A time of day in a picker - bound, and one-way with the write back by hand.
struct TimePickerSample: SampleContent, ExampleContent {
    @State private var alarm = ClockTime(hour: 7, minute: 30)
    @State private var picks = 0

    static let id = "timePicker"
    static let title = "TimePicker"
    static let summary = "A time of day - three integers, the way a date is three integers."

    static let code = """
        @State private var alarm = ClockTime(hour: 7, minute: 30)
        @State private var picks = 0

        VStack {
            // `alarm` is printed below, so picking a time builds this closure;
            // the picker itself is handed the state.
            DebugInfoLabel()

            TimePicker($alarm)
                .format("t")

            Label("Alarm at \\(alarm.text)")

            HStack {
                Button("Morning")
                    .onClicked { alarm = ClockTime(hour: 7, minute: 30) }

                Button("Lunch")
                    .onClicked { alarm = ClockTime(hour: 12, minute: 0) }

                Button("Evening")
                    .onClicked { alarm = ClockTime(hour: 21, minute: 5) }
            }

            // The same time, one-way: `.time` is what puts it in the field,
            // and the write back is by hand.
            TimePicker()
                .time(alarm)
                .format("t")
                .onTimeChanged { time in
                    alarm = time
                    picks += 1
                }

            Label(picks == 0
                ? "onTimeChanged has not fired"
                : "onTimeChanged: \\(alarm.text), \\(picks) so far")
        }
        """

    var content: any View {
        VStack {
            DebugInfoLabel()

            TimePicker($alarm)
                .automationId("timePicker.alarm")
                .semanticDescription("Alarm")
                .format("t")

            Label("Alarm at \(alarm.text)")
                .fontSize(17)
                .horizontalTextAlignment(.center)

            HStack {
                Button("Morning")
                    .fontSize(13)
                    .padding(16, 6)
                    .onClicked { alarm = ClockTime(hour: 7, minute: 30) }

                Button("Lunch")
                    .fontSize(13)
                    .padding(16, 6)
                    .onClicked { alarm = ClockTime(hour: 12, minute: 0) }

                Button("Evening")
                    .fontSize(13)
                    .padding(16, 6)
                    .onClicked { alarm = ClockTime(hour: 21, minute: 5) }
            }
            .spacing(10)
            .horizontalAlignment(.center)

            SectionTitle("One-way, written back by hand")

            TimePicker()
                .automationId("timePicker.alarm.oneWay")
                .semanticDescription("Alarm, written back by hand")
                .time(alarm)
                .format("t")
                .onTimeChanged { time in
                    alarm = time
                    picks += 1
                }

            Label(picks == 0
                ? "onTimeChanged has not fired"
                : "onTimeChanged: \(alarm.text), \(picks) so far")
                .fontSize(13)
                .horizontalTextAlignment(.center)
        }
        .spacing(12)
    }

    var notes: Element? {
        VStack {
            Label("A `ClockTime` rather than a Foundation value, for the reason a "
                + "`CalendarDate` is not a `Date`: formatting one needs ICU, and ICU is "
                + "the dependency this library cannot take. It is three numbers - hour, "
                + "minute, second - and whether the reader sees 21:05 or 9:05 PM is the "
                + "host's to decide, from the reader's locale and the `.format`.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("`TimePicker()` says nothing about a time, so `.time` is what puts one "
                + "in the field - the form a `Style<TimePicker>` or a picker built "
                + "elsewhere has to use. Nothing comes back on its own either: the "
                + "`alarm = time` in `onTimeChanged` is exactly the write the binding "
                + "above makes for you, which is why both fields move together.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The count answers the READER: the three buttons write `alarm` from the "
                + "tree, both fields follow, and no event fires.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
