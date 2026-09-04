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

            var content: Element {
                VStack {
                    Label(locale.name)
                    Label("zone · \\(locale.timeZone)")
                    Label("clock · \\(locale.uses24HourClock ? "24h" : "12h")")
                    Label("week starts · \\(locale.firstDayOfWeek)")
                    Label(locale.isMetric ? "metric" : "not metric")
                }
            }
        }
        """

    var example: Element {
        VStack {
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
        Label("This is the standing answer to two measured holes: on "
            + "Android, Swift's Locale.current is a fallback en_001, and "
            + "on Windows the app's Foundation links no zones at all - "
            + "while the HOST knows all of it. The zone is the IANA name, "
            + "Windows names converted, the TimeZoneInfo.local() rule. "
            + "Formatting still crosses the boundary invariant; this is "
            + "for LOGIC - a first weekday, a 24-hour clock, a unit.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
