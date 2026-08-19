import StateUI

/// MAUI: TimePicker.
struct TimePickerSample: SampleContent {
    @State private var alarm = ClockTime(hour: 7, minute: 30)

    static let id = "timePicker"
    static let title = "TimePicker"
    static let summary = "A time of day - three integers, the way a date is three integers."

    static let code = """
        @State private var alarm = ClockTime(hour: 7, minute: 30)

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
        }
        .spacing(12)
    }
}
