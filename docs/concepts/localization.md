# Localization

Localization chooses the values that depend on the user's language and
region. A value can be a word, a message with arguments, a typeface, a
picture, or anything else a part of the application shows - localization is
typed resources, not a table of strings. Everything is written in Swift: the
application's resources in its own types, and the plural rules and formats in
StateUI. The same session therefore writes the same text on every platform,
and a test proves the exact text without a host.

Three things decide what a user sees, and none overrides another:

| What | Examples | Chosen by |
| --- | --- | --- |
| Resources | words, messages, typefaces, pictures, accessibility text | the language, matched to the application's |
| Formats | numbers, days, times, lists | `formatLocale`, independent of the language |
| Presentation | text size, contrast, theme, motion | the system's settings and styles, not localization |

A user may read an English interface with Polish numbers and a larger text
size: each choice has its own source.

Three types carry localization:

- a **catalog** (`LocalizationCatalog`) names the application's languages and
  the one it falls back to - nothing else, so it never grows;
- a **part** (`LocalizedResources`) is one screen's, feature's or document's
  resources, in every language of the catalog, beside the views that show it;
- a **localization** (`Localization`) holds which language, formats and zone
  are in effect, as state the application owns and gives to a branch.

## A complete example

"Files" shows a folder: its title, a search field, how many files it holds, a
language setting, and a folder report - a document written in its recipient's
language, whatever the interface speaks. It speaks English and Polish. Each
part of the application has its own resources beside its views, and each
language of a part is a file of its own:

```text
Files/
  FilesApp.swift
  AppLanguage.swift         the languages, and the catalog
  TextStyleSpec.swift
  FileItem.swift
  Files/
    FilesResources.swift    the part, and its switch over the languages
    FilesEnglish.swift
    FilesPolish.swift
    FilesRoot.swift
    FilesPage.swift
  Settings/
    SettingsResources.swift
    SettingsEnglish.swift
    SettingsPolish.swift
    LanguageSettings.swift
  Report/
    ReportResources.swift
    ReportEnglish.swift
    ReportPolish.swift
    ReportPage.swift
    ReportView.swift
```

The whole application, file after file:

```swift
// FilesApp.swift

struct FilesApp: Application {
    var body: some Scene {
        WindowGroup { FilesRoot() }
    }
}

@_cdecl("stateui_app_register")
@MainActor
public func stateui_app_register() {
    stateUIUseApp(FilesApp())
}

// AppLanguage.swift

/// The languages Files speaks, in its interface and in its documents.
enum AppLanguage: LocaleTag, CaseIterable {
    case english = "en"
    case polish = "pl"
}

/// Files' languages, and the one it falls back to.
enum AppCatalog: LocalizationCatalog {
    static let defaultLanguage = AppLanguage.english
}

// TextStyleSpec.swift

/// A base typeface; the user's text size still scales it.
struct TextStyleSpec {
    let size: Double
    let lineHeight: Double
}

// FileItem.swift

/// A file the folder holds: data, so it reads the same in every language.
struct FileItem: Hashable {
    let name: String
    let modified: CalendarDate
}

// Files/FilesResources.swift

/// What the file list shows.
struct FilesResources: LocalizedResources {
    typealias Catalog = AppCatalog

    let title: String
    let searchPlaceholder: String
    let fileCount: Message<Int>
    let showReport: String
    let reportLanguage: String
    let heading: TextStyleSpec
    let emptyState: ImageSource

    static func resources(for language: AppLanguage) -> FilesResources {
        switch language {
        case .english: .english
        case .polish: .polish
        }
    }
}

// Files/FilesEnglish.swift

extension FilesResources {
    static let english = FilesResources(
        title: "Files",
        searchPlaceholder: "Search files",
        fileCount: Message { count, context in
            let number = context.number(count)
            return context.plural(count, one: "\(number) file", other: "\(number) files")
        },
        showReport: "Folder report",
        reportLanguage: "Report language",
        heading: TextStyleSpec(size: 24, lineHeight: 1.15),
        emptyState: ImageSource(light: "files_empty.png", dark: "files_empty_dark.png"))
}

// Files/FilesPolish.swift

extension FilesResources {
    static let polish = FilesResources(
        title: "Pliki",
        searchPlaceholder: "Szukaj plików",
        fileCount: Message { count, context in
            let number = context.number(count)
            return context.plural(
                count,
                one: "\(number) plik",
                few: "\(number) pliki",
                many: "\(number) plików",
                other: "\(number) pliku")
        },
        showReport: "Raport folderu",
        reportLanguage: "Język raportu",
        heading: TextStyleSpec(size: 24, lineHeight: 1.15),
        emptyState: ImageSource(light: "files_empty.png", dark: "files_empty_dark.png"))
}

// Files/FilesRoot.swift

/// The window's view: it owns the interface's localization and gives it to the page.
struct FilesRoot: View {
    @State private var localization = Localization(AppCatalog.self)

    var body: some View {
        FilesPage()
            .environment(localization)
    }
}

// Files/FilesPage.swift

struct FilesPage: View {
    @Environment private var res: FilesResources
    @Environment private var localization: Localization<AppCatalog>
    @State private var query = ""
    @State private var showsReport = false
    private let files = [
        FileItem(name: "Plan.pdf", modified: CalendarDate(year: 2026, month: 9, day: 30)),
        FileItem(name: "Budżet.xlsx", modified: CalendarDate(year: 2026, month: 10, day: 2)),
        FileItem(name: "Notes.txt", modified: CalendarDate(year: 2026, month: 10, day: 9)),
    ]

    var body: some View {
        VStack {
            Text(res.title)
                .fontSize(res.heading.size)
                .lineHeight(res.heading.lineHeight)

            SearchField($query)
                .placeholder(res.searchPlaceholder)

            Text(localization.text(res.fileCount, files.count))

            if files.isEmpty {
                Image(res.emptyState)
                    .isAccessibilityHidden(true)
            }

            Button(res.showReport)
                .onClicked { showsReport.toggle() }

            if showsReport {
                ReportPage(files: files)
            }

            LanguageSettings()
        }
        .spacing(12)
        .title(res.title)
    }
}

// Settings/SettingsResources.swift

/// What the language setting shows.
struct SettingsResources: LocalizedResources {
    typealias Catalog = AppCatalog

    let interfaceLanguage: String
    let sameAsSystem: String

    static func resources(for language: AppLanguage) -> SettingsResources {
        switch language {
        case .english: .english
        case .polish: .polish
        }
    }
}

// Settings/SettingsEnglish.swift

extension SettingsResources {
    static let english = SettingsResources(interfaceLanguage: "Interface language", sameAsSystem: "Same as system")
}

// Settings/SettingsPolish.swift

extension SettingsResources {
    static let polish = SettingsResources(interfaceLanguage: "Język interfejsu", sameAsSystem: "Jak w systemie")
}

// Settings/LanguageSettings.swift

/// The interface's language: the system's, or one Files speaks. A language's name is its own, in every language.
struct LanguageSettings: View {
    @Environment private var res: SettingsResources
    @Environment private var localization: Localization<AppCatalog>

    var body: some View {
        VStack {
            Text(res.interfaceLanguage)
            HStack {
                Button(res.sameAsSystem)
                    .onClicked { localization.language = .system }
                Button("English")
                    .onClicked { localization.language = .fixed(.english) }
                Button("Polski")
                    .onClicked { localization.language = .fixed(.polish) }
            }
        }
    }
}

// Report/ReportResources.swift

/// What the folder report says: the document's own words.
struct ReportResources: LocalizedResources {
    typealias Catalog = AppCatalog

    let heading: String
    let prepared: Message<CalendarDate>
    let fileCount: Message<Int>
    let modifiedColumn: String
    let footer: String

    static func resources(for language: AppLanguage) -> ReportResources {
        switch language {
        case .english: .english
        case .polish: .polish
        }
    }
}

// Report/ReportEnglish.swift

extension ReportResources {
    static let english = ReportResources(
        heading: "Folder report",
        prepared: Message { day, context in
            "Prepared on \(context.date(day, style: .long))"
        },
        fileCount: Message { count, context in
            let number = context.number(count)
            return context.plural(
                count, one: "The folder holds \(number) file.", other: "The folder holds \(number) files.")
        },
        modifiedColumn: "Modified",
        footer: "Generated by Files")
}

// Report/ReportPolish.swift

extension ReportResources {
    static let polish = ReportResources(
        heading: "Raport folderu",
        prepared: Message { day, context in
            "Sporządzono \(context.date(day, style: .long))"
        },
        fileCount: Message { count, context in
            let number = context.number(count)
            return context.plural(
                count,
                one: "Folder zawiera \(number) plik.",
                few: "Folder zawiera \(number) pliki.",
                many: "Folder zawiera \(number) plików.",
                other: "Folder zawiera \(number) pliku.")
        },
        modifiedColumn: "Zmieniono",
        footer: "Wygenerowano w aplikacji Pliki")
}

// Report/ReportPage.swift

/// The report's page: its buttons speak the interface's language, the document its own.
struct ReportPage: View {
    @Environment private var res: FilesResources
    @State private var report = Localization(
        AppCatalog.self, language: .fixed(.polish), formatLocale: .fixed("pl-PL"))
    let files: [FileItem]

    var body: some View {
        VStack {
            Text(res.reportLanguage)
            HStack {
                Button("English").onClicked {
                    report.language = .fixed(.english)
                    report.formatLocale = .fixed("en-US")
                }
                Button("Polski").onClicked {
                    report.language = .fixed(.polish)
                    report.formatLocale = .fixed("pl-PL")
                }
            }

            ReportView(files: files, prepared: CalendarDate(year: 2026, month: 10, day: 11))
                .environment(report)

            Grid {
                ReportView(files: files, prepared: CalendarDate(year: 2026, month: 10, day: 11))
                    .environment(report.speaking(.english))
                ReportView(files: files, prepared: CalendarDate(year: 2026, month: 10, day: 11))
                    .environment(report.speaking(.polish))
                    .gridColumn(1)
            }
            .columns(.fill, .fill)
        }
    }
}

// Report/ReportView.swift

/// The document: every word and every date in it follows the nearest localization - the report's.
struct ReportView: View {
    @Environment private var res: ReportResources
    @Environment private var localization: Localization<AppCatalog>
    let files: [FileItem]
    let prepared: CalendarDate

    var body: some View {
        VStack {
            Text(res.heading)
            Text(localization.text(res.prepared, prepared))
            Text(localization.text(res.fileCount, files.count))
            Text(res.modifiedColumn)
            ForEach(files) { file in
                HStack {
                    Text(file.name)
                    Text(localization.date(file.modified, style: .medium))
                }
            }
            Text(res.footer)
        }
        .spacing(6)
    }
}
```

What it shows, with the interface in English and the report in Polish, and
the other way round:

| Interface | Report | The interface says | The report says |
| --- | --- | --- | --- |
| English | Polish | Files · 3 files · Report language | Raport folderu · Sporządzono 11 października 2026 · Folder zawiera 3 pliki. · 30 wrz 2026 |
| Polish | English | Pliki · 3 pliki · Język raportu | Folder report · Prepared on October 11, 2026 · The folder holds 3 files. · Sep 30, 2026 |

A file's name is data, so `Budżet.xlsx` reads the same in both. The sections
below take the example apart.

## The catalog and its parts

`AppCatalog` holds the languages and `defaultLanguage`. The raw value of each
language is its tag - `"en"`, `"pl"`, or `"sr-Latn"` where a script tells two
variants apart. Name the enum after the application, as `AppLanguage` is:
inside a catalog, `Language` names the catalog's own language type, so an
enum called `Language` does not compile there.

A part is a struct whose fields are any values: `String`, `Message`, a
typeface, an `ImageSource` - the theme then picks the picture's light or dark
file, so localization does not handle the theme again. Its `switch` over the
catalog's languages is the only place that lists them, and each language is a
`static let` in a file of its own. A new part is a new folder and touches no
shared file, so no dictionary grows into one place. The compiler guards the
rest:

- a new field of `FilesResources` does not compile until `FilesEnglish.swift`
  and `FilesPolish.swift` give it - other parts are not touched;
- a new language in `AppLanguage` does not compile until every part's
  `switch` names it, each error in that part's folder;
- a message given a wrong argument does not compile.

The compiler cannot tell whether a translation is right, whether a picture
exists or whether a typeface has a script's glyphs: those are the
application's tests.

## Giving and reading a localization

`FilesRoot` owns a `Localization` in its `@State` and gives it to the page with
`.environment(localization)`, as any object of the application is given.
Below it, a view reads:

- a part, by its type: `@Environment private var res: FilesResources` - it
  comes in the language of the nearest `Localization` of its catalog;
- the localization itself, by its type: `@Environment private var
  localization: Localization<AppCatalog>` - to say a message, to write a
  number or a day, or to change a choice.

A part with no localization of its catalog above stops the program with both
names, as an object nobody gave does. A part lends nothing: `$res.title` does
not compile, because a part is a value, not an object to write through.

## Changing the language

`LanguageSettings` writes `localization.language`. The language is state, so
exactly the bodies that read a part or a format through this localization are
built again; `FilesRoot`, which only passes the reference, is not. Nothing
derived is stored - `resolvedLanguage` and every part are worked out on each
read - so nothing can go stale.

A change of language changes what the views show, not the data or the
identity of the interface: typed text, navigation, selection and running work
stay. A page is not rebuilt from scratch by `.id(localization.resolvedLanguage)`,
which would replace it instead of updating it.

Keep values, not finished text, in state. `@State var message = res.title`
keeps the old language after a change; keep the count, the day or a
`KeyPath<FilesResources, String>`, and turn it into text in the body.

## A document in its own language

`ReportPage` owns a second `Localization` for the report, fixed to the
recipient's language and formats, and gives it to `ReportView`. The nearest
localization wins, so everything in the report's branch speaks Polish while
the page around it speaks the interface's language. A change of the
interface's language does not build the report again, and a change of the
report's does not touch the interface. In an application whose documents are
saved, the report's choices are saved with the document: they belong to it,
not to the window.

## A fragment in another language

`report.speaking(.english)` is the same localization speaking English: its
formats and zone follow the report's until it is given its own. It answers
the same object for the same language, so a branch given it on every render
is not built again for nothing. The pair under the report shows one
document in two languages side by side, in two equal columns, so each wraps
its text within half the width on a phone.

## Messages and plural forms

A `Message` is a field like any other. Each language says the whole sentence
in its own order and grammar, so a translation is never glued from pieces.
It knows nothing of where it is said: `localization.text(res.fileCount, count)`
hands it the context - the grammar of `resolvedLanguage` and the formats in
effect.

`context.plural` picks the form by the language's rule. English takes one and
other; Polish takes one (1), few (2-4, 22-24, ... but not 12-14) and many (0,
5-21, 25-31, ... and 112). `other` is always given; a form the language needs
that the message lacks is said once in debug, and `other` stands in.
`context.isolated(name)` sets a file name or an address between Unicode's
isolation marks, so it keeps its place inside a right-to-left sentence.
Several arguments are a tuple or a struct: `Message<(name: String, count:
Int)>`.

## Formats

The same formats are on the localization and on a message's context, and
StateUI writes them itself:

```swift
enum ShopLanguage: LocaleTag, CaseIterable {
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
        localization.number(12_345.5),                      // 12 345,5
        localization.percent(0.25),                         // 25%
        localization.date(day, style: .long),               // 30 September 2026
        localization.date(day, style: .short),              // 30.09.2026
        localization.time(ClockTime(hour: 7, minute: 30)),  // 07:30
        localization.list(["Ania", "Basia", "Celina"]),     // Ania, Basia, and Celina
    ]
}
```

| Part of the text | Follows |
| --- | --- |
| digits, the decimal and grouping separators | `formatLocale` |
| the order of a day's parts, the 12- or 24-hour clock | `formatLocale`'s region |
| month names, the words of a list and of a clock | the sentence's language, `resolvedLanguage` |
| an order the language's grammar fixes | the language: a Polish date says "30 września 2026" in every region |

An English sentence with Polish formats therefore says "30 September 2026"
and writes `12 345,5`; Polish groups digits only from five up (`1234`,
`12 345`). StateUI writes English and Polish today, with the formats of the
United States, the United Kingdom and Poland. A language or region it does not
write yet is said once in debug and written in English with the United
States' formats.

## Which language is in effect

Each choice of a `Localization` is `.system` or `.fixed(value)`:

- `language` - with `.system`, the first of the user's languages the catalog
  speaks: the same tag, then the same language in the same script (the script
  a language is written in where the tag says none: `sr` is Cyrillic), then the
  language alone where the catalog has it bare; the catalog's
  `defaultLanguage` where none matches;
- `formatLocale` - with `.system`, the language in effect with the system's
  region and clock;
- `timeZone` - the zone the host's zone acts are asked about,
  `resolvedTimeZone`.

A user who prefers `de-CH`, then `pl-PL`, then `en-US` sees Files in Polish.
Every part on the screen comes whole from that one language, so a word and its
typeface never come from two variants.

## The library's own words

A dialog shows its own captions where the application gives none:
`window.alert` its "OK", `window.prompt` its "OK" and "Cancel". StateUI says
them in the system's language - Polish "Anuluj" on a Polish system - as the
platform's own buttons beside them do. An application that speaks another
language than the system's passes its own captions from its resources.

## What a host adds

Every word and number above is worked out in Swift before anything reaches a
host. Three things belong to the hosts and are still to come:

- the language of a branch's text, for a screen reader's pronunciation,
  hyphenation and the glyphs of Han characters;
- the formats and zone of native date and time pickers, which write their own
  months;
- the user's ordered languages, which `\.locale.languages` holds; until a host
  fills it, `language` and `name` stand in.

## Related contracts

- [Environment](environment.md) covers `.environment(_:)`, `@Environment` and
  the locale facts a localization follows.
- [State and reactivity](state-and-reactivity.md) covers how a write rebuilds
  exactly its readers.
