# Localization

Localization chooses the values that depend on the user's language and
region: words, messages, typefaces, pictures, the way a number or a day is
written. It is typed resources in Swift, not a table of strings: a part of an
application is a struct whose fields are any values, and each language is one
`static let` of it. Everything is written in Swift - the application's
resources, the plural rules and the formats - so the same session writes the
same text on every host, and a test proves the exact text without one.

## A language is a tag

`LocaleTag` is a BCP 47 tag read into its parts: a language, a script, a
region. The script is part of the language: `sr-Latn` and `sr-Cyrl` are two
variants, and folding both into `sr` loses what tells them apart. Where a tag
says no script, `likelyScript` answers the one its language is written in, from
a small table in Swift - Serbian is Cyrillic, Chinese in Taiwan is Traditional.
The same script decides the direction: Arabic, Hebrew and their kin are written
right to left.

A tag is kept in its standard spelling (`pl-PL`, `zh-Hant-TW`), so two
spellings of one tag compare equal. A POSIX locale such as `pl_PL.UTF-8@euro`
reads as its language and region. Text that is no tag is kept as written and
says so with `isValid`; a match never takes it.

## A catalog and its parts

A catalog (`LocalizationCatalog`) is an application's languages - an enum
whose raw values are tags - and the language that stands in where none of the
user's matches. It holds nothing else, so it never grows with the application.

The resources live in parts (`LocalizedResources`): one struct for each screen,
feature or document, beside the views that show it, with a `switch` over the
catalog's languages and a file for each language. A new part touches no shared
file; a new field fails to compile until every language file of its part says
it; a new language fails to compile in every part until each says it. The
compiler cannot check that a translation is right, that a picture exists or
that a typeface has a script's glyphs - those are tests.

The catalog's language type is its associated type `Language`, so inside a
catalog that name is taken: an application enum called `Language` makes
`Language.english` a reference to the catalog's own type, which the compiler
reports as a recursion. The handbook names the enum after the application.

A part falls back whole, never a field at a time: every part on a screen comes
in one language, so a word and its typeface never come from two variants.

## Three choices

What is localized has three sources, and none overrides another. The language
picks the resources. The formats (`formatLocale`) write numbers, days and times.
The zone (`timeZone`) is the one the host's zone acts are asked about. A user
may read an English interface with Polish numbers in Warsaw's zone. Text size,
contrast and motion are the user's settings and styles' work, not localization:
a part chooses a base typeface, and the system's scaling still applies to it.

Each choice is a `LocaleChoice`: `.system`, which follows the host's facts and
their changes, or `.fixed(value)`.

## One object in state

`Localization<Catalog>` holds the three choices as state and works out what
follows from them on every read: `resolvedLanguage`, the parts, the formats.
Nothing derived is stored, so nothing can go stale. The application owns it in
a `@State` and gives it to a branch with `.environment(_:)`, like any object of
its own; there is no process-wide localization. The nearest one wins, so a
document gives its own and everything in its branch speaks the document's
language, while the interface around it speaks the user's.

`speaking(_:)` makes a fragment in another language: an object whose language
is fixed and whose formats and zone follow its base until it is given its own.
The base keeps one for each language, held weakly - what renders it keeps it
alive - so a branch given `localization.speaking(.english)` on every render is
given the same object and is not rebuilt for nothing.

## Reading a part

`@Environment private var res: FilesResources` is a slot keyed by the part's
localization type, `Localization<FilesResources.Catalog>`. The differ fills it
with the nearest one, and the read answers the part in that localization's
`resolvedLanguage`. The language is state, so a body that read a part is
rebuilt when it changes, and only that body: the provider passes a reference
and reads nothing. A part with no localization of its catalog above stops the
program with both names, as an object nobody provided does.

A part is a value and lends nothing: `$res.title` does not compile, because the
lender needs a reference to write through.

## Matching a language

`.system` takes the user's languages in order - the host's ordered list, or
its one language where it gives none - and the first the catalog speaks:

1. the same tag;
2. the same language in the same script, the script worked out where unsaid;
3. the language alone, where the catalog has it bare.

None matching, the catalog's `defaultLanguage` speaks. A user preferring
`de-CH`, `pl-PL`, `en-US` of a catalog in English and Polish gets Polish; one
with `sr-Latn-RS` gets `sr-Latn`, not the Cyrillic variant.

## Messages

`Message<Arguments>` is a field like any other: each language says the whole
sentence in its own order and grammar, so a translation is never glued from
pieces. It knows nothing of where it is said; `localization.text(message,
arguments)` hands it the context - the grammar of `resolvedLanguage` and the
formats in effect. Several arguments are a tuple or a struct.

`plural` picks the form a count takes by the language's rule: English one and
other, Polish one, few and many (`112` ends in 12, so it is many). `other` is
always given; a form the language needs and the message lacks is said once in
debug, and `other` stands in. `isolated(_:)` sets inserted text - a file name,
an address - between Unicode's isolate marks, so a Latin name keeps its place
in a right-to-left sentence.

## Formats in Swift

The formats are StateUI's own, written by hand: one file for each language
under `Types/Localization/Languages` holds its plural rule, its month names as
a date says them (Polish in the genitive: "30 września 2026"), the words of a
list and of a twelve-hour clock, and the regions whose formats StateUI writes
for it. No engine of the platform is asked, so the text is the same on every
host; the price is that a language is work in StateUI, and a user's own
patterns in the system's settings are not read - only the facts the host
reports (the 24-hour clock where the formats are the system's).

The words of a format follow the sentence's language; the digits, separators,
the order of a day's parts and the clock follow the formats' region. An English
sentence with Polish formats says "30 September 2026" and writes `12 345,5`.
An order the language's grammar fixes stays: a Polish month in the genitive
follows its day, so a Polish sentence with American formats says "30 września
2026" - "września 30" is no Polish - while its digits stay American, `9/30/26`.
A language or region StateUI does not write yet is said once and written in
English and the United States' formats.
