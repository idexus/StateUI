// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Which language and which formats hold in a branch: what the application chose, and what follows from it.
///
///     @State private var localization = Localization(AppCatalog.self)
///
///     var body: some View {
///         FilesPage()
///             .environment(localization)
///     }
///
/// It is given with `.environment(_:)`, like any object of the application, and the nearest one wins - a document
/// gives its own. A view reads a part of the resources with `@Environment private var res: FilesResources`, and
/// this object with `@Environment private var localization: Localization<AppCatalog>`: to say a message, to write a
/// number or a day, or to change a choice. Each choice is state, so a change rebuilds the views that read what
/// follows from it.
///
/// Design: docs/design/types/localization.md#one-object-in-state
@MainActor
public final class Localization<Catalog: LocalizationCatalog> {
    /// Which language the resources speak: one of the catalog's, or nil - the default - for the user's, as the
    /// system says it, changes included.
    ///
    ///     Picker([nil, .english, .polish], selection: localization.$language) { $0.map { "\($0)" } ?? "As the system" }
    @State public var language: Catalog.CatalogLanguage?

    /// Which formats numbers, days and times are written in: a tag such as `"pl-PL"`, or nil for the system's. On
    /// one made by `speaking(_:)`, nil follows its base's.
    @State public var formatLocale: LocaleTag?

    /// Which time zone holds: a named one, or nil for the system's. On one made by `speaking(_:)`, nil follows its
    /// base's.
    @State public var timeZone: TimeZoneName?

    private let base: Localization<Catalog>?
    private var spoken: [Catalog.CatalogLanguage: Spoken] = [:]

    /// A localization of `catalog`'s languages; every choice not given follows the system.
    public init(
        _ catalog: Catalog.Type,
        language: Catalog.CatalogLanguage? = nil,
        formatLocale: LocaleTag? = nil,
        timeZone: TimeZoneName? = nil
    ) {
        base = nil
        _language = State(wrappedValue: language)
        _formatLocale = State(wrappedValue: formatLocale)
        _timeZone = State(wrappedValue: timeZone)
    }

    private init(speaking language: Catalog.CatalogLanguage, over base: Localization<Catalog>) {
        self.base = base
        _language = State(wrappedValue: language)
        _formatLocale = State(wrappedValue: nil)
        _timeZone = State(wrappedValue: nil)
    }

    /// The language in use: the one chosen, or the first of the user's languages the catalog speaks - its
    /// `defaultLanguage` where none is.
    public var resolvedLanguage: Catalog.CatalogLanguage {
        language ?? Self.matching(Self.preferences(of: StandardEnvironment.locale)) ?? Catalog.defaultLanguage
    }

    /// The zone in use, for the clock's acts - `application.clock.utcOffset(of: localization.resolvedTimeZone)`: the
    /// one chosen here or above, else the user's; nil while the host has not said, which the clock reads as the
    /// user's own.
    public var resolvedTimeZone: TimeZoneName? {
        chosenTimeZone ?? StandardEnvironment.locale.timeZone
    }

    /// The formats chosen here, or above where none is; nil where the system's hold.
    private var chosenFormatLocale: LocaleTag? { formatLocale ?? base?.chosenFormatLocale }

    /// The zone chosen here, or above where none is; nil where the system's holds.
    private var chosenTimeZone: TimeZoneName? { timeZone ?? base?.chosenTimeZone }

    /// The same localization speaking `language`, for a part of the screen: one stable object for each language,
    /// its formats and zone following this one's.
    ///
    ///     ReportView().environment(localization.speaking(.english))
    public func speaking(_ language: Catalog.CatalogLanguage) -> Localization<Catalog> {
        if let kept = spoken[language]?.localization { return kept }

        let made = Localization(speaking: language, over: self)
        spoken[language] = Spoken(made)
        return made
    }

    /// A message said in `resolvedLanguage`, with the formats in effect.
    public func text<Arguments>(_ message: Message<Arguments>, _ arguments: Arguments) -> String {
        message.say(arguments, context)
    }

    /// The form for `count` in `resolvedLanguage` - `MessageContext.plural`.
    public func plural(
        _ count: Int, zero: String? = nil, one: String? = nil, two: String? = nil, few: String? = nil,
        many: String? = nil, other: String
    ) -> String {
        context.plural(count, zero: zero, one: one, two: two, few: few, many: many, other: other)
    }

    /// A whole number in the formats in effect - `MessageContext.number`.
    public func number(_ value: Int) -> String { context.number(value) }

    /// A number with a fraction in the formats in effect - `MessageContext.number`.
    public func number(_ value: Double, fractionDigits: Int? = nil) -> String {
        context.number(value, fractionDigits: fractionDigits)
    }

    /// A share as a percentage - `MessageContext.percent`.
    public func percent(_ value: Double, fractionDigits: Int = 0) -> String {
        context.percent(value, fractionDigits: fractionDigits)
    }

    /// A day - `MessageContext.date`.
    public func date(_ day: CalendarDate, format: DateFormat = .short) -> String { context.date(day, format: format) }

    /// A time of day - `MessageContext.time`.
    public func time(_ time: ClockTime, format: TimeFormat = .short) -> String { context.time(time, format: format) }

    /// Items as a sentence lists them - `MessageContext.list`.
    public func list(_ items: [String]) -> String { context.list(items) }

    /// Text isolated from the sentence's direction - `MessageContext.isolated`.
    public func isolated(_ text: String) -> String { context.isolated(text) }

    /// The grammar of `resolvedLanguage` with the formats in effect: the words follow the language, the digits and
    /// the order follow the formats - the system's region and clock where they are the system's.
    var context: MessageContext {
        let system = StandardEnvironment.locale
        let speaks = resolvedLanguage.rawValue
        let formats: LocaleTag
        var clock: Bool?
        if let tag = chosenFormatLocale {
            formats = tag
        } else {
            let parts = [speaks.language, speaks.script, system.language?.region]
            formats = LocaleTag(parts.compactMap { $0 }.joined(separator: "-"))
            clock = system.language == nil ? nil : system.uses24HourClock
        }
        let region = RegionConventions.of(formats)
        return MessageContext(
            language: speaks, words: .of(speaks), region: region, uses24HourClock: clock ?? region.uses24HourClock)
    }

    /// The user's languages, in order: the host's list, or its one language where it gives none.
    static func preferences(of system: LocaleInfo) -> [LocaleTag] {
        if !system.languages.isEmpty { return system.languages }
        return system.language.map { [$0] } ?? []
    }

    /// The first of `wanted` the catalog speaks: the same tag, then the same language in the same script, then
    /// the language alone where the catalog has it bare.
    /// Design: docs/design/types/localization.md#matching-a-language
    static func matching(_ wanted: [LocaleTag]) -> Catalog.CatalogLanguage? {
        let offered = Catalog.CatalogLanguage.allCases.map { (language: $0, tag: $0.rawValue) }
        for tag in wanted where tag.isValid {
            if let same = offered.first(where: { $0.tag == tag }) { return same.language }
            if let written = offered.first(where: {
                $0.tag.language == tag.language && $0.tag.likelyScript == tag.likelyScript
            }) { return written.language }
            if let bare = offered.first(where: { $0.tag.identifier == tag.language }) { return bare.language }
        }
        return nil
    }

    /// A localization `speaking(_:)` made, held weakly: what renders it keeps it alive.
    private final class Spoken {
        weak var localization: Localization<Catalog>?

        init(_ localization: Localization<Catalog>) {
            self.localization = localization
        }
    }
}
