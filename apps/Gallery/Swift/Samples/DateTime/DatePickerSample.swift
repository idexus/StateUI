import StateUI

/// MAUI: DatePicker.
struct DatePickerSample: SampleContent {
    @State private var due = CalendarDate(year: 2026, month: 8, day: 2)
    @State private var chosen = ""
    @State private var picks = 0

    static let id = "datePicker"
    static let title = "DatePicker"
    static let summary = "A day chosen from a calendar - three integers, not a Foundation Date."

    static let code = """
        @State private var due = CalendarDate(year: 2026, month: 8, day: 2)
        @State private var chosen = ""
        @State private var picks = 0

        VStack {
            DatePicker($due)
                .minimumDate(CalendarDate(year: 2020, month: 1, day: 1))
                .maximumDate(CalendarDate(year: 2030, month: 12, day: 31))
                .format("D")
                .onDateSelected { date in
                    chosen = date.text
                    picks += 1
                }

            Label("Due \\(due.text)")

            Label(picks == 0
                ? "onDateSelected has not fired"
                : "onDateSelected: \\(chosen), \\(picks) so far")

            // A day written from the TREE is not a pick: the field moves and
            // the count stays where it is.
            Button("Push it to New Year")
                .onClicked { due = CalendarDate(year: 2027, month: 1, day: 1) }
        }
        """

    var content: Element {
        VStack {
            DatePicker($due)
                .minimumDate(CalendarDate(year: 2020, month: 1, day: 1))
                .maximumDate(CalendarDate(year: 2030, month: 12, day: 31))
                .format("D")
                .onDateSelected { date in
                    chosen = date.text
                    picks += 1
                }

            Label("Due \(due.text)")
                .fontSize(17)
                .horizontalTextAlignment(.center)

            Label(picks == 0
                ? "onDateSelected has not fired"
                : "onDateSelected: \(chosen), \(picks) so far")
                .fontSize(13)
                .horizontalTextAlignment(.center)

            Button("Push it to New Year")
                .fontSize(13)
                .padding(16, 6)
                .horizontalOptions(.center)
                .onClicked { due = CalendarDate(year: 2027, month: 1, day: 1) }

            Label("The binding and the event are two halves of one choice: `$due` takes "
                + "the chosen day into state, and `onDateSelected` runs after that write "
                + "with the same day - which is where anything beyond holding the value "
                + "belongs. The button writes `due` from the tree instead, and the count "
                + "stays put: the event answers the READER picking a day and nothing "
                + "else.")
                .fontSize(12)
                .textColor(Palette.subtle)

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
