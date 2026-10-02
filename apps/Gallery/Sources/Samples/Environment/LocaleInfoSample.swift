import StateUI

/// The user's language, region, zone and calendar habits - the HOST's
/// answer, which is the point: Swift's own `Locale.current` is a fallback
/// `en_001` on Android, and a Windows app's Foundation has no zones at all.
struct LocaleInfoSample: SampleContent, ExampleContent {
    /// The locale, as the host reports it.
    @Environment var locale: LocaleInfo

    static let id = "locale"
    static let title = "LocaleInfo"
    static let summary = "Language, region, time zone and calendar habits - "
        + "the host's answer, on every platform."

    static let code = """
        struct LocaleBadge: ContentView {
            @Environment var locale: LocaleInfo

            var content: some View {
                VStack {
                    // The locale is read here, so a change to it builds this
                    // closure.
                    DebugInfoLabel()

                    Text(locale.name)
                    Text("language · \\(locale.language)")
                    Text("region · \\(locale.region.isEmpty ? "none" : locale.region)")
                    Text("zone · \\(locale.timeZone)")
                    Text("clock · \\(locale.uses24HourClock ? "24h" : "12h")")
                    Text("week starts · \\(locale.firstDayOfWeek)")
                    Text(locale.isMetric ? "metric" : "not metric")
                }
            }
        }
        """

    var content: some View {
        VStack {
            DebugInfoLabel()

            Text(locale.name.isEmpty ? "the host has not said" : locale.name)
                .fontSize(28)
                .fontAttributes(.bold)
                .horizontalTextAlignment(.center)

            Text("language · \(locale.language)")
                .fontSize(15)
            Text("region · \(locale.region.isEmpty ? "none" : locale.region)")
                .fontSize(15)
            Text("zone · \(locale.timeZone)")
                .fontSize(15)
            Text("clock · \(locale.uses24HourClock ? "24-hour" : "12-hour")")
                .fontSize(15)
            Text("week starts · \(locale.firstDayOfWeek)")
                .fontSize(15)
            Text(locale.isMetric ? "metric" : "not metric")
                .fontSize(15)
        }
        .spacing(10)
    }

    var notes: (any View)? {
        Text("This is the host's answer on every platform, the zone an "
            + "IANA name everywhere. It is for LOGIC - a first weekday, a "
            + "24-hour clock, a unit - not for formatting.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
