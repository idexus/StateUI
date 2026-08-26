import StateUI

/// MAUI: TimePicker.
struct TimePickerSample: SampleContent {
    @State private var alarm = ClockTime(hour: 7, minute: 30)
    @State private var picks = 0

    static let id = "timePicker"
    static let title = "TimePicker"
    static let summary = "A time of day - three integers, the way a date is three integers."

    static let code = """
        @State private var alarm = ClockTime(hour: 7, minute: 30)
        @State private var picks = 0

        VStack {
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
                .onTimeSelected { time in
                    alarm = time
                    picks += 1
                }

            Label(picks == 0
                ? "onTimeSelected has not fired"
                : "onTimeSelected: \\(alarm.text), \\(picks) so far")
        }

        // ClockTime(hour: 7, minute: 30) travels as "07:30:00"
        """

    var content: Element {
        VStack {
            TimePicker($alarm)
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
            .horizontalOptions(.center)

            Label("A ClockTime rather than a Foundation value, for the reason a "
                + "CalendarDate is not a Date: formatting one needs ICU, and ICU is the "
                + "dependency this library cannot take. It travels as 07:30:00 and C# "
                + "parses it into the TimeSpan MAUI wants - a length since midnight.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Whether the reader sees 21:05 or 9:05 PM is the FORMAT, applied on the "
                + "C# side where a locale costs nothing.")
                .fontSize(12)
                .textColor(Palette.subtle)

            SectionTitle("ONE-WAY, WRITTEN BACK BY HAND")

            TimePicker()
                .time(alarm)
                .format("t")
                .onTimeSelected { time in
                    alarm = time
                    picks += 1
                }

            Label(picks == 0
                ? "onTimeSelected has not fired"
                : "onTimeSelected: \(alarm.text), \(picks) so far")
                .fontSize(13)
                .horizontalTextAlignment(.center)
        }
        .spacing(12)
    }

    var notes: Element? {
        VStack {
            Label("`TimePicker()` says nothing about a time, so `.time` is what puts one "
                + "in the field - the form a `Style<TimePicker>` or a picker built "
                + "elsewhere has to use. Nothing comes back on its own either: the "
                + "`alarm = time` in `onTimeSelected` is exactly the write the binding "
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
