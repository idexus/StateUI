# Localization

Localization chooses the values that depend on the user's language and
region. A value can be a word, a message with arguments, a typeface, a
picture, or anything else a part of the application shows. Everything is
written in Swift, in the application's own types. The library writes plural
forms and formats itself, so the same text appears on every platform.

Three types carry it:

- `LocalizationCatalog` names the application's languages and the one it
  falls back to;
- `LocalizedResources` is one part's resources - a screen's, a feature's, a
  document's - in every language of the catalog;
- `Localization` holds which language and which formats are in effect, as
  state the application owns.

## Languages, parts and a view

A catalog holds the languages and nothing else, so it never grows. Each part
of the application has its own resources beside its views, with one `static
let` for each language - in a real application, a file for each:

```swift
enum AppLanguage: String, CaseIterable, Sendable {
    case english = "en"
    case polish = "pl"
}

enum AppCatalog: LocalizationCatalog {
    static let defaultLanguage = AppLanguage.english
}

struct FilesResources: LocalizedResources {
    typealias Catalog = AppCatalog

    let title: String
    let fileCount: Message<Int>

    static func resources(for language: AppLanguage) -> FilesResources {
        switch language {
        case .english: .english
        case .polish: .polish
        }
    }
}

extension FilesResources {
    static let english = FilesResources(
        title: "Files",
        fileCount: Message { count, context in
            let number = context.number(count)
            return context.plural(count, one: "\(number) file", other: "\(number) files")
        })
}

extension FilesResources {
    static let polish = FilesResources(
        title: "Pliki",
        fileCount: Message { count, context in
            let number = context.number(count)
            return context.plural(
                count,
                one: "\(number) plik",
                few: "\(number) pliki",
                many: "\(number) plików",
                other: "\(number) pliku")
        })
}

struct FilesPage: View {
    @Environment private var res: FilesResources
    @Environment private var localization: Localization<AppCatalog>
    let count: Int

    var body: some View {
        VStack {
            Text(res.title)
            Text(localization.text(res.fileCount, count))
            Button("Polski")
                .onClicked { localization.language = .fixed(.polish) }
        }
    }
}

struct FilesRoot: View {
    @State private var localization = Localization(AppCatalog.self)

    var body: some View {
        FilesPage(count: 22)
            .environment(localization)
    }
}
```

Name the language enum after the application, as `AppLanguage` is: inside a
catalog, `Language` names the catalog's own language type, so an enum called
`Language` does not compile there.

`@Environment private var res: FilesResources` reads the part in the language
of the nearest `Localization` of its catalog. The localization is an object of
the application, given with `.environment(_:)` like any other. A new field of a
part does not compile until every language of that part says it; a new
language does not compile until every part has it.

## Choices and what follows from them

A `Localization` holds three choices, each `.system` or `.fixed(value)`:

- `language`, which picks the resources;
- `formatLocale`, which writes numbers, days and times - an English interface
  may write Polish numbers;
- `timeZone`, the zone the host's zone acts are asked about
  (`resolvedTimeZone`).

What follows from them is worked out on every read, never stored:
`resolvedLanguage`, every part, and the formats. A write to a choice rebuilds
exactly the views that read a part or a format through it.

With `.system`, the language is the first of the user's languages the catalog
speaks - the same tag, then the same language in the same script, then the
language alone - and the catalog's `defaultLanguage` where none is. A part
always comes whole from one language.

## A document in its own language

The nearest localization wins. A document holds its own, so its words and
formats follow the document while the interface around it follows the user:

```swift
enum ReportLanguage: String, CaseIterable, Sendable {
    case english = "en"
    case polish = "pl"
}

enum ReportCatalog: LocalizationCatalog {
    static let defaultLanguage = ReportLanguage.english
}

struct ReportResources: LocalizedResources {
    typealias Catalog = ReportCatalog

    let heading: String

    static func resources(for language: ReportLanguage) -> ReportResources {
        switch language {
        case .english: ReportResources(heading: "Folder report")
        case .polish: ReportResources(heading: "Raport folderu")
        }
    }
}

struct ReportView: View {
    @Environment private var res: ReportResources

    var body: some View {
        Text(res.heading)
    }
}

struct ReportPage: View {
    @State private var report = Localization(
        ReportCatalog.self, language: .fixed(.polish), formatLocale: .fixed("pl-PL"))

    var body: some View {
        VStack {
            ReportView()
                .environment(report)

            HStack {
                ReportView()
                    .environment(report.speaking(.english))
                ReportView()
                    .environment(report.speaking(.polish))
            }
        }
    }
}
```

`speaking(_:)` gives a fragment another language and keeps its base's formats
and zone. It answers the same object for the same language, so a branch given
it on every render is not rebuilt for nothing.

## Messages and formats

A `Message` is a field like any other; each language says the whole sentence,
in its own order and grammar. `localization.text(message, arguments)` says it
with the grammar of `resolvedLanguage` and the formats in effect. `plural`
picks a form by the language's rule - English one and other; Polish one, few
and many - and a form the language needs that the message lacks is said once
in debug. `isolated(_:)` keeps a file name or an address in its place inside a
right-to-left sentence.

The same formats are on the localization and on a message's context:

```swift
enum ShopLanguage: String, CaseIterable, Sendable {
    case english = "en"
    case polish = "pl"
}

enum ShopCatalog: LocalizationCatalog {
    static let defaultLanguage = ShopLanguage.english
}

@MainActor
func written() -> [String] {
    let localization = Localization(ShopCatalog.self, language: .fixed(.english), formatLocale: .fixed("pl-PL"))
    let day = CalendarDate(year: 2026, month: 9, day: 30)

    return [
        localization.number(12_345.5),          // 12 345,5
        localization.percent(0.25),             // 25%
        localization.date(day, style: .long),   // 30 September 2026
        localization.time(ClockTime(hour: 7, minute: 30)), // 07:30
        localization.list(["Ania", "Basia", "Celina"]),     // Ania, Basia, and Celina
    ]
}
```

The words of a format follow the language of the sentence; the digits, the
separators, the order of a day's parts and the clock follow `formatLocale`. An
English sentence with Polish formats therefore says "30 September 2026" and
writes `12 345,5`. An order the language's grammar fixes stays: a Polish date
says "30 września 2026" whatever the region.

StateUI writes English and Polish today, with the formats of the United
States, the United Kingdom and Poland. A language or region it does not write
yet is said once in debug and written in English with the United States'
formats.

## What a host adds

Every word and number above is worked out in Swift before anything reaches a
host. Three parts belong to the hosts and are planned:

- the language of a branch's text, for a screen reader's pronunciation,
  hyphenation and the glyphs of Han characters;
- the formats and zone of native pickers, which write their own months;
- the user's ordered languages, which `\.locale.languages` holds and which a
  host fills in; until it does, `language` and `name` stand in.

## Related contracts

- [Environment](environment.md) covers `.environment(_:)`, `@Environment` and
  the locale facts a localization follows.
- [State and reactivity](state-and-reactivity.md) covers how a write rebuilds
  exactly its readers.
