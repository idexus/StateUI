import StateUI

/// MAUI: DatePicker.
struct DatePickerSample: SampleContent {
    @State private var due = CalendarDate(year: 2026, month: 8, day: 2)

    static let id = "datePicker"
    static let title = "DatePicker"
    static let summary = "A day chosen from a calendar - three integers, not a Foundation Date."

    static let code = """
        @State private var due = CalendarDate(year: 2026, month: 8, day: 2)

        VStack {
            DatePicker($due)
                .minimumDate(CalendarDate(year: 2020, month: 1, day: 1))
                .maximumDate(CalendarDate(year: 2030, month: 12, day: 31))
                .format("D")

            Label("Due \\(due.text)")
        }
        """

    var content: Element {
        VStack {
            DatePicker($due)
                .minimumDate(CalendarDate(year: 2020, month: 1, day: 1))
                .maximumDate(CalendarDate(year: 2030, month: 12, day: 31))
                .format("D")

            Label("Due \(due.text)")
                .fontSize(17)
                .horizontalTextAlignment(.center)

            Label("A CalendarDate rather than a Date: formatting a Date needs a "
                + "DateFormatter, a DateFormatter needs ICU, and ICU is the one "
                + "dependency this library cannot take. It travels as 2026-08-02 into "
                + "the renderer, and a day picked on screen comes back as its three "
                + "numbers.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The FORMAT is .NET's, applied on the C# side where a calendar and a "
                + "locale cost nothing.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
