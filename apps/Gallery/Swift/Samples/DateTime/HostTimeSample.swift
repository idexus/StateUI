import StateUI

/// The library's own way to tell the time: acts, not Foundation.
struct HostTimeSample: SampleContent {
    @State private var zone = ""
    @State private var clocks: [(String, String)] = []
    @State private var season = ""

    /// A few zones a reader will recognize, including one at half past the
    /// hour - Kolkata is +05:30, and an offset held as minutes is what makes
    /// that ordinary rather than a special case.
    static let cities = [
        "UTC", "America/New_York", "Europe/Warsaw", "Asia/Kolkata", "Asia/Tokyo",
    ]

    static let id = "hostTime"
    static let title = "Host time"
    static let summary = "The clock, the zone and the offset - asked of the host, "
        + "the same answer on four platforms."

    static let code = """
        @State private var zone = ""
        @State private var clocks: [(String, String)] = []
        @State private var season = ""

        static let cities = [
            "UTC", "America/New_York", "Europe/Warsaw", "Asia/Kolkata", "Asia/Tokyo",
        ]

        VStack {
            Label("Here: \\(zone)")
            Label(season)

            ForEach(clocks, id: \\.0) { clock in
                HStack {
                    Label(clock.0)
                    Label(clock.1)
                }
            }

            Button("Read again")
                .onClicked { try await read() }
        }
        .onLoaded { try await read() }

        func read() async throws {
            zone = try await TimeZoneInfo.local()

            let now = try await ClockTime.now()
            let here = try await TimeZoneInfo.getUtcOffset()
            let winter = try await TimeZoneInfo.getUtcOffset(
                on: CalendarDate(year: 2026, month: 1, day: 15))

            season = "Offset now \\(offsetText(here)), on 15 January \\(offsetText(winter))"

            var found: [(String, String)] = []
            for city in Self.cities {
                let there = try await TimeZoneInfo.getUtcOffset(of: city)
                found.append((city, "\\(shifted(now, by: there - here).text)  \\(offsetText(there))"))
            }

            clocks = found
        }

        /// The same time of day, seen from another zone: seconds since midnight
        /// plus the difference between the two offsets, wrapped into the day.
        func shifted(_ time: ClockTime, by difference: Duration) -> ClockTime {
            let midnight = time.hour * 3600 + time.minute * 60 + time.second
            let moved = midnight + Int(difference.components.seconds)
            let day = (moved % 86400 + 86400) % 86400

            return ClockTime(hour: day / 3600, minute: (day % 3600) / 60, second: day % 60)
        }

        func offsetText(_ offset: Duration) -> String {
            let minutes = Int(offset.components.seconds) / 60
            let sign = minutes < 0 ? "-" : "+"
            let hh = abs(minutes) / 60
            let mm = abs(minutes) % 60

            return "UTC\\(sign)\\(hh < 10 ? "0" : "")\\(hh):\\(mm < 10 ? "0" : "")\\(mm)"
        }
        """

    var example: Element {
        VStack {
            Label("Here: \(zone.isEmpty ? "…" : zone)")
                .fontSize(17)
                .fontAttributes(.bold)

            Label(season)
                .fontSize(13)
                .textColor(Palette.subtle)

            ForEach(clocks, id: \.0) { clock in
                HStack {
                    Label(clock.0)
                        .fontSize(14)
                        .horizontalOptions(.start)

                    Label(clock.1)
                        .fontSize(14)
                        .textColor(Palette.accent)
                        .horizontalOptions(.end)
                        .horizontalTextAlignment(.end)
                }
                .spacing(12)
            }

            Button("Read again")
                .fontSize(13)
                .padding(16, 6)
                .horizontalOptions(.center)
                .onClicked { try await read() }
        }
        .spacing(10)
        .onLoaded { try await read() }
    }

    var notes: Element? {
        VStack {
            Label("Every line above crossed the boundary as an act - DateTime.Now, "
                + "TimeZoneInfo.Local, TimeZoneInfo.GetUtcOffset - and came back as a "
                + "ClockTime and a Duration, both of which this side owns. No Foundation "
                + "is involved, which is why the answers are the same on iOS, Android, "
                + "macOS and Windows.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("An offset is minutes on the wire, so +05:30 is not a special case, "
                + "and it is asked for a DAY - which is how the same zone answers "
                + "differently in January than it does in August.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(10)
    }

    /// One reading: the zone, the host's clock, and each city seen from it.
    private func read() async throws {
        zone = try await TimeZoneInfo.local()

        let now = try await ClockTime.now()
        let here = try await TimeZoneInfo.getUtcOffset()
        let winter = try await TimeZoneInfo.getUtcOffset(
            on: CalendarDate(year: 2026, month: 1, day: 15))

        season = "Offset now \(offsetText(here)), on 15 January \(offsetText(winter))"

        var found: [(String, String)] = []
        for city in Self.cities {
            let there = try await TimeZoneInfo.getUtcOffset(of: city)
            found.append((city, "\(shifted(now, by: there - here).text)  \(offsetText(there))"))
        }

        clocks = found
    }
}

/// The same time of day, seen from another zone: seconds since midnight plus
/// the difference between the two offsets, wrapped into the day.
private func shifted(_ time: ClockTime, by difference: Duration) -> ClockTime {
    let midnight = time.hour * 3600 + time.minute * 60 + time.second
    let moved = midnight + Int(difference.components.seconds)
    let day = (moved % 86400 + 86400) % 86400

    return ClockTime(hour: day / 3600, minute: (day % 3600) / 60, second: day % 60)
}

/// `UTC+05:30`, written by hand - a formatter is Foundation, and this sample is
/// about not needing one.
private func offsetText(_ offset: Duration) -> String {
    let minutes = Int(offset.components.seconds) / 60
    let sign = minutes < 0 ? "-" : "+"
    let hh = abs(minutes) / 60
    let mm = abs(minutes) % 60

    return "UTC\(sign)\(hh < 10 ? "0" : "")\(hh):\(mm < 10 ? "0" : "")\(mm)"
}
