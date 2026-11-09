import StateUI

/// A document in its own language: a folder report whose words, plural forms and dates come from Swift
/// resources, one file for each language, through the report's own localization.
struct LocalizationSample: SampleContent, ExampleContent {
    // listing: LocalizationSample
    @State private var localization = Localization(
        ReportCatalog.self, language: .polish, formatLocale: "pl-PL")
    @State private var count = 22.0
    private let prepared = CalendarDate(year: 2026, month: 10, day: 11)
    private let recent = [
        FileItem(name: "Plan.pdf", modified: CalendarDate(year: 2026, month: 9, day: 30)),
        FileItem(name: "Budżet.xlsx", modified: CalendarDate(year: 2026, month: 10, day: 2)),
        FileItem(name: "Notes.txt", modified: CalendarDate(year: 2026, month: 10, day: 9)),
    ]
    // listing: end

    static let id = "localization"
    static let title = "Localization"
    static let summary = "A document in its own language - words, plural forms and dates from Swift resources."

    // listing: LocalizationSample
    var body: some View {
        VStack {
            HStack {
                Picker([nil, ReportLanguage.english, .polish], selection: localization.$language) { language in
                    language.map { $0 == .english ? "English" : "Polski" } ?? "As the system"
                }
                Picker([nil, LocaleTag("en-US"), "pl-PL"], selection: localization.$formatLocale) { formats in
                    formats.map { "Formats \($0)" } ?? "The system's formats"
                }
            }
            .spacing(8)

            HStack {
                Stepper($count)
                    .minimum(0)
                    .maximum(30)
                Text("\(Int(count))")
            }
            .spacing(8)

            ReportView(fileCount: Int(count), recent: recent, prepared: prepared)
                .environment(localization)

            Text("Side by side")
                .fontWeight(.bold)
            Grid {
                ReportView(fileCount: Int(count), recent: recent, prepared: prepared)
                    .environment(localization.speaking(.english))
                ReportView(fileCount: Int(count), recent: recent, prepared: prepared)
                    .environment(localization.speaking(.polish))
                    .gridColumn(1)
            }
            .columns(.fill, .fill)
            .columnSpacing(16)
        }
        .spacing(14)
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("The report has its own localization, held in this view's state and given with "
                + "`.environment(localization)`. Its words come from `ReportResources`, one file for "
                + "each language, read with `@Environment private var res: ReportResources`.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Choose the language and the formats apart - English words in Polish formats - each "
                + "through its binding, `localization.$language` and `localization.$formatLocale`; nil "
                + "follows the system.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Step the count: Polish says 2 pliki, 5 plików, 22 pliki - the plural rule is "
                + "StateUI's, written in Swift. The dates follow the report's formats.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("The pair below speaks one language each with `localization.speaking(_:)` and "
                + "keeps the report's formats: with Polish ones the English copy says \"Prepared on "
                + "11 October 2026\" - English words in Polish order.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Turn on a screen reader that follows a text's language: each copy is read in the language "
                + "its localization speaks, the page around it in the system's.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(10)
    }
}
