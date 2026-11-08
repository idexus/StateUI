// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a message is said with: the grammar of its language and the formats in effect. A `Localization` offers
/// the same words, so a view and a message write a number alike.
///
/// Words inside a format - months, the "and" of a list - follow the language; digits, separators, the order of a
/// day's parts and the clock follow the formats (`Localization.formatLocale`), except an order the language's
/// grammar fixes: a Polish month in the genitive always follows its day.
///
/// Design: docs/design/types/localization.md#formats-in-swift
public struct MessageContext: Sendable {
    let language: LocaleTag
    let words: LanguageConventions
    let region: RegionConventions
    let uses24HourClock: Bool

    /// The form for `count` in the message's language. `other` is always needed; a form the language needs and
    /// the message lacks is said once in debug, and `other` stands in.
    public func plural(
        _ count: Int, zero: String? = nil, one: String? = nil, two: String? = nil, few: String? = nil,
        many: String? = nil, other: String
    ) -> String {
        let category = words.plural(count)
        let forms: [PluralCategory: String?] = [.zero: zero, .one: one, .two: two, .few: few, .many: many, .other: other]
        if let form = forms[category] ?? nil { return form }

        complain("A message in \(language) needs its \"\(category)\" form for \(count); it says its \"other\".")
        return other
    }

    /// A whole number: `12,345` in English, `12 345` in Polish.
    public func number(_ value: Int) -> String {
        (value < 0 ? "-" : "") + grouped(String(value.magnitude))
    }

    /// A number with a fraction: up to three digits after the point, or exactly `fractionDigits` - nine at most -
    /// rounded half away from zero. Written in full whatever its size, from the digits Swift writes for it - the
    /// shortest that read back as the same number; infinity and not-a-number keep Swift's spelling.
    public func number(_ value: Double, fractionDigits: Int? = nil) -> String {
        guard value.isFinite else { return String(value) }
        let places = max(0, min(fractionDigits ?? 3, 9))
        var (whole, fraction) = Self.digits(of: value.magnitude)
        if fraction.count > places {
            let cut = fraction.index(fraction.startIndex, offsetBy: places)
            let up = fraction[cut] >= "5"
            fraction = String(fraction[..<cut])
            if up {
                let carried = Self.incremented(whole + fraction)
                whole = String(carried.dropLast(places))
                fraction = String(carried.suffix(places))
            }
        }
        fraction += String(repeating: "0", count: places - fraction.count)
        if fractionDigits == nil { while fraction.last == "0" { fraction.removeLast() } }

        let text = grouped(whole) + (fraction.isEmpty ? "" : region.decimal + fraction)
        let nothing = (whole + fraction).allSatisfy { $0 == "0" }
        return (value < 0 && !nothing ? "-" : "") + text
    }

    /// The digits of `magnitude` before and after the point, from the shortest Swift writes - `12345.5`, `1e+20`,
    /// `1.5e-07` - with no exponent left.
    private static func digits(of magnitude: Double) -> (whole: String, fraction: String) {
        let written = String(magnitude).split(separator: "e")
        let mantissa = written[0].split(separator: ".", omittingEmptySubsequences: false)
        let digits = mantissa.joined()
        let point = mantissa[0].count + (written.count > 1 ? Int(written[1]) ?? 0 : 0)
        if point <= 0 { return ("0", String(repeating: "0", count: -point) + digits) }
        if point >= digits.count { return (digits + String(repeating: "0", count: point - digits.count), "") }
        return (String(digits.prefix(point)), String(digits.dropFirst(point)))
    }

    /// `digits` one more, carried: `0999` is `1000`.
    private static func incremented(_ digits: String) -> String {
        var carried = Array(digits.utf8)
        var at = carried.count - 1
        while at >= 0 {
            guard carried[at] == UInt8(ascii: "9") else {
                carried[at] += 1
                return String(decoding: carried, as: UTF8.self)
            }
            carried[at] = UInt8(ascii: "0")
            at -= 1
        }
        return "1" + String(decoding: carried, as: UTF8.self)
    }

    /// A share as a percentage: `0.25` is `25%`.
    public func percent(_ value: Double, fractionDigits: Int = 0) -> String {
        number(value * 100, fractionDigits: fractionDigits) + "%"
    }

    /// A day: `September 30, 2026`, `30 września 2026`, `30.09.2026`.
    public func date(_ day: CalendarDate, format: DateFormat = .short) -> String {
        let month = max(1, min(day.month, 12)) - 1
        switch format {
        case .long, .medium:
            let name = (format == .long ? words.months : words.shortMonths)[month]
            return words.dayFirst ?? region.dayFirst
                ? "\(day.day) \(name) \(day.year)" : "\(name) \(day.day), \(day.year)"
        case .short:
            let form = region.numericDate
            let pad = { (number: Int) in form.padded && number < 10 ? "0\(number)" : "\(number)" }
            let short = day.year % 100
            let year = form.fullYear ? "\(day.year)" : short < 10 ? "0\(short)" : "\(short)"
            let parts = form.dayFirst ? [pad(day.day), pad(day.month), year] : [pad(day.month), pad(day.day), year]
            return parts.joined(separator: form.separator)
        }
    }

    /// A time of day: `07:30` on a 24-hour clock, `7:30 AM` on a twelve-hour one; `.medium` adds the seconds,
    /// `07:30:05`.
    public func time(_ time: ClockTime, format: TimeFormat = .short) -> String {
        func twoDigits(_ value: Int) -> String { value < 10 ? "0\(value)" : "\(value)" }
        let minutes = twoDigits(time.minute) + (format == .medium ? ":" + twoDigits(time.second) : "")
        guard !uses24HourClock else { return twoDigits(time.hour) + ":" + minutes }

        let hour = time.hour % 12 == 0 ? 12 : time.hour % 12
        return "\(hour):\(minutes)\u{202F}" + (time.hour < 12 ? words.morning : words.evening)
    }

    /// Items as a sentence lists them: `Ania, Basia, and Celina`, `Ania, Basia i Celina`.
    public func list(_ items: [String]) -> String {
        guard let last = items.last else { return "" }
        guard items.count > 1 else { return last }

        let head = items.dropLast().joined(separator: ", ")
        let comma = items.count > 2 && words.serialComma ? "," : ""
        return "\(head)\(comma) \(words.and) \(last)"
    }

    /// Text set into a sentence - a file name, an address - isolated from the sentence's direction, so a Latin name
    /// keeps its place in an Arabic sentence.
    public func isolated(_ text: String) -> String {
        "\u{2068}\(text)\u{2069}"
    }

    private func grouped(_ digits: String) -> String {
        guard digits.count >= 3 + region.minimumGroupingDigits else { return digits }

        var groups: [Substring] = []
        var end = digits.endIndex
        while end > digits.startIndex {
            let start = digits.index(end, offsetBy: -3, limitedBy: digits.startIndex) ?? digits.startIndex
            groups.insert(digits[start..<end], at: 0)
            end = start
        }
        return groups.joined(separator: region.grouping)
    }
}
