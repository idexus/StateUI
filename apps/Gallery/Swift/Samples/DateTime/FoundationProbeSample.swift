import StateUI
import Foundation

#if canImport(Android)
import Android
#endif

// What Foundation answers on this platform, measured live rather than
// remembered. The LIBRARY never imports Foundation - a date on the wire stays
// three integers - but an APPLICATION may: on Apple the system's Foundation,
// on Android and Windows the Swift-rewritten one, whose Internationalization
// half carries its own, namespaced ICU. The one trap is Android's current
// zone, and the first two lines of the handler are the fix.
struct FoundationProbeSample: SampleContent {
    @State private var rows: [(String, String)] = []

    static let id = "foundationProbe"
    static let title = "Foundation probe"
    static let summary = "Dates, zones and JSON from Foundation itself - and the one "
        + "line Android needs first."

    static let code = """
        import Foundation

        #if canImport(Android)
        import Android
        #endif

        @State private var rows: [(String, String)] = []

        VStack {
            ForEach(rows, id: \\.0) { row in
                VStack {
                    Label(row.0)
                    Label(row.1)
                }
            }
        }
        .onLoaded {
            let hostZone = try await TimeZoneInfo.local()

            #if canImport(Android)
            // Android's tz database is packed in a format Foundation cannot
            // read, so the current zone comes up GMT. The TZ variable is read
            // before any detection, and ICU's own tzdata answers for the named
            // zone - the host says where the device is, once, before the first
            // TimeZone use.
            setenv("TZ", hostZone, 1)
            #endif

            var found: [(String, String)] = []
            found.append(("Host TimeZoneInfo.Local", hostZone))

            let now = Date()
            let zone = TimeZone.current
            found.append(("TimeZone.current",
                "\\(zone.identifier), \\(offsetText(zone.secondsFromGMT(for: now)))"))

            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = zone
            let parts = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute, .second], from: now)
            found.append(("Calendar, local time",
                "\\(parts.year ?? 0)-\\(pad(parts.month))-\\(pad(parts.day)) "
                + "\\(pad(parts.hour)):\\(pad(parts.minute)):\\(pad(parts.second))"))

            let host = try await ClockTime.now()
            found.append(("Host DateTime.Now", host.text))

            found.append(("ISO8601Format", now.ISO8601Format()))

            if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) {
                let t = calendar.dateComponents([.year, .month, .day], from: tomorrow)
                found.append(("Calendar, +1 day",
                    "\\(t.year ?? 0)-\\(pad(t.month))-\\(pad(t.day))"))
            }

            let january = calendar.date(from: DateComponents(year: 2026, month: 1, day: 15))
            found.append(("Offset on 2026-01-15",
                january.map { offsetText(zone.secondsFromGMT(for: $0)) } ?? "no date"))

            if let named = TimeZone(identifier: hostZone) {
                let winter = january.map { offsetText(named.secondsFromGMT(for: $0)) } ?? "no date"
                found.append(("TimeZone(\\"\\(hostZone)\\")",
                    "\\(offsetText(named.secondsFromGMT(for: now))) now, \\(winter) in January"))
            } else {
                found.append(("TimeZone(\\"\\(hostZone)\\")", "nil - the identifier is unknown here"))
            }

            found.append(("Locale.current", Locale.current.identifier))

            let json = (try? JSONEncoder().encode(["probe": 1])) ?? Data()
            found.append(("JSONEncoder", String(decoding: json, as: UTF8.self)))

            for row in found { print("FOUNDATION-PROBE \\(row.0): \\(row.1)") }
            rows = found
        }

        func pad(_ value: Int?) -> String {
            let v = value ?? 0
            return v < 10 && v >= 0 ? "0\\(v)" : "\\(v)"
        }

        func offsetText(_ seconds: Int) -> String {
            let sign = seconds < 0 ? "-" : "+"
            let h = abs(seconds) / 3600
            let m = (abs(seconds) % 3600) / 60
            return "GMT\\(sign)\\(pad(h)):\\(pad(m))"
        }
        """

    var content: Element {
        VStack {
            Label("What Foundation answers on this platform - each row is one question:")
                .fontSize(12)
                .textColor(Palette.subtle)

            ForEach(rows, id: \.0) { row in
                VStack {
                    Label(row.0)
                        .fontSize(11)
                        .textColor(Palette.subtle)

                    Label(row.1)
                        .fontSize(15)
                }
                .spacing(1)
            }
        }
        .spacing(10)
        .onLoaded {
            let hostZone = try await TimeZoneInfo.local()

            #if canImport(Android)
            // Android's tz database is packed in a format Foundation cannot
            // read, so the current zone comes up GMT. The TZ variable is read
            // before any detection, and ICU's own tzdata answers for the named
            // zone - the host says where the device is, once, before the first
            // TimeZone use.
            setenv("TZ", hostZone, 1)
            #endif

            var found: [(String, String)] = []
            found.append(("Host TimeZoneInfo.Local", hostZone))

            let now = Date()
            let zone = TimeZone.current
            found.append(("TimeZone.current",
                "\(zone.identifier), \(offsetText(zone.secondsFromGMT(for: now)))"))

            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = zone
            let parts = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute, .second], from: now)
            found.append(("Calendar, local time",
                "\(parts.year ?? 0)-\(pad(parts.month))-\(pad(parts.day)) "
                + "\(pad(parts.hour)):\(pad(parts.minute)):\(pad(parts.second))"))

            let host = try await ClockTime.now()
            found.append(("Host DateTime.Now", host.text))

            found.append(("ISO8601Format", now.ISO8601Format()))

            if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) {
                let t = calendar.dateComponents([.year, .month, .day], from: tomorrow)
                found.append(("Calendar, +1 day",
                    "\(t.year ?? 0)-\(pad(t.month))-\(pad(t.day))"))
            }

            let january = calendar.date(from: DateComponents(year: 2026, month: 1, day: 15))
            found.append(("Offset on 2026-01-15",
                january.map { offsetText(zone.secondsFromGMT(for: $0)) } ?? "no date"))

            // Whether the tz DATABASE is readable at all, apart from whether
            // the current zone was detected - the difference between "zones do
            // not work" and "the host has to say which zone, once". The zone
            // asked for is the one the HOST named, not one written down here:
            // the question is the same wherever the machine is, and a literal
            // would only ask it about somebody else's city.
            if let named = TimeZone(identifier: hostZone) {
                let winter = january.map { offsetText(named.secondsFromGMT(for: $0)) } ?? "no date"
                found.append(("TimeZone(\"\(hostZone)\")",
                    "\(offsetText(named.secondsFromGMT(for: now))) now, \(winter) in January"))
            } else {
                found.append(("TimeZone(\"\(hostZone)\")", "nil - the identifier is unknown here"))
            }

            found.append(("Locale.current", Locale.current.identifier))

            let json = (try? JSONEncoder().encode(["probe": 1])) ?? Data()
            found.append(("JSONEncoder", String(decoding: json, as: UTF8.self)))

            for row in found { print("FOUNDATION-PROBE \(row.0): \(row.1)") }
            rows = found
        }
    }

    var notes: Element? {
        VStack {
            Label("The library still crosses the boundary with three-integer dates - "
                + "Foundation here is the application's own import. On Apple it is the "
                + "system's; on Android it is swift-foundation, whose zones come from an "
                + "ICU it carries itself.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Android cannot detect the current zone - its tz database is packed "
                + "in a format Foundation does not read, so TimeZone.current starts as "
                + "GMT. The host knows the zone, so the handler asks it and sets TZ "
                + "before Foundation first looks. Every row above depends on that one "
                + "line.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Windows fails one step earlier: only FoundationEssentials is linked "
                + "there, so there is no zone database for TZ to name. Dates, calendar "
                + "arithmetic, ISO8601 and JSON are right; TimeZone.current is GMT, a "
                + "named zone is nil and Locale.current is a fallback. The host row is "
                + "the answer on that platform, the way the host's time already is.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(10)
    }
}

// By hand, not String(format:) - the probe must not assume more of Foundation
// than the question it asks.
private func pad(_ value: Int?) -> String {
    let v = value ?? 0
    return v < 10 && v >= 0 ? "0\(v)" : "\(v)"
}

private func offsetText(_ seconds: Int) -> String {
    let sign = seconds < 0 ? "-" : "+"
    let h = abs(seconds) / 3600
    let m = (abs(seconds) % 3600) / 60
    return "GMT\(sign)\(pad(h)):\(pad(m))"
}
