import StateUI

/// The reader's language, region, zone and calendar habits - the HOST's
/// answer, which is the point: Swift's own `Locale.current` is a fallback
/// `en_001` on Android, and a Windows app's Foundation has no zones at all.
struct LocaleInfoSample: SampleContent {
    /// The locale, as the host reports it.
    @Environment var locale: LocaleInfo

    static let id = "locale"
    static let title = "LocaleInfo"
    static let summary = "Language, region, time zone and calendar habits - "
        + "the host's answer, on every platform."

    static let code = """
        struct LocaleBadge: ContentView {
            @Environment var locale: LocaleInfo

            var content: any View {
                VStack {
                    // The locale is read here, so a change to it builds this
                    // closure.
                    DebugInfoLabel()

                    Label(locale.name)
                    Label("language · \\(locale.language)")
                    Label("region · \\(locale.region.isEmpty ? "none" : locale.region)")
                    Label("zone · \\(locale.timeZone)")
                    Label("clock · \\(locale.uses24HourClock ? "24h" : "12h")")
                    Label("week starts · \\(locale.firstDayOfWeek)")
                    Label(locale.isMetric ? "metric" : "not metric")
                }
            }
        }
        """

    var content: any View {
        VStack {
            DebugInfoLabel()

            Label(locale.name.isEmpty ? "the host has not said" : locale.name)
                .fontSize(28)
                .fontAttributes(.bold)
                .horizontalTextAlignment(.center)

            Label("language · \(locale.language)")
                .fontSize(15)
            Label("region · \(locale.region.isEmpty ? "none" : locale.region)")
                .fontSize(15)
            Label("zone · \(locale.timeZone)")
                .fontSize(15)
            Label("clock · \(locale.uses24HourClock ? "24-hour" : "12-hour")")
                .fontSize(15)
            Label("week starts · \(locale.firstDayOfWeek)")
                .fontSize(15)
            Label(locale.isMetric ? "metric" : "not metric")
                .fontSize(15)
        }
        .spacing(10)
    }

    var notes: Element? {
        Label("This is the host's answer on every platform, the zone an "
            + "IANA name everywhere. It is for LOGIC - a first weekday, a "
            + "24-hour clock, a unit - not for formatting.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
