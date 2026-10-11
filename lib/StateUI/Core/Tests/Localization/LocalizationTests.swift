// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A localization: which language it resolves to, and the parts of resources a view reads through it.
//
// The promises pinned here:
//
//   - `.system` follows the user's languages in order, the catalog's default where none matches;
//   - a part read with `@Environment` comes in the nearest localization's language;
//   - a change of language rebuilds the readers and never the provider, nor a document with its own;
//   - `speaking(_:)` is one stable object per language, its formats following its base.

import XCTest
@_spi(Host) @testable import StateUI

enum TestLanguage: String, CaseIterable, Sendable {
    case english = "en"
    case polish = "pl"
}

enum TestCatalog: LocalizationCatalog {
    static let defaultLanguage = TestLanguage.english
}

struct TestWords: LocalizedResources {
    typealias Catalog = TestCatalog

    let save: String
    let files: Message<Int>

    static func resources(for language: TestLanguage) -> TestWords {
        switch language {
        case .english: .english
        case .polish: .polish
        }
    }

    static let english = TestWords(
        save: "Save",
        files: Message { count, context in
            let number = context.number(count)
            return context.plural(count, one: "\(number) file", other: "\(number) files")
        })

    static let polish = TestWords(
        save: "Zapisz",
        files: Message { count, context in
            let number = context.number(count)
            return context.plural(
                count, one: "\(number) plik", few: "\(number) pliki", many: "\(number) plików",
                other: "\(number) pliku")
        })
}

enum Serbian: String, CaseIterable, Sendable {
    case cyrillic = "sr-Cyrl"
    case latin = "sr-Latn"
}

enum SerbianCatalog: LocalizationCatalog {
    static let defaultLanguage = Serbian.cyrillic
}

/// Counts how often a body ran.
private final class Builds {
    var count = 0
}

/// Reads one part of the resources - the view a change of language rebuilds.
private struct SaveLabel: View {
    let builds: Builds
    @Environment var words: TestWords

    var body: some View {
        builds.count += 1
        return ModifiedContent(node: label(words.save))
    }
}

/// Owns a localization, gives it, and reads nothing of it.
private struct Provider: View {
    let builds: Builds
    let reader: Builds
    let localization: Localization<TestCatalog>

    var body: some View {
        builds.count += 1
        return ModifiedContent(node: stack([SaveLabel(builds: reader).environment(localization).node]))
    }
}

/// The interface and a document beside it, each with its own localization.
private struct InterfaceAndDocument: View {
    let interfaceReader: Builds
    let documentReader: Builds
    let interface: Localization<TestCatalog>
    let document: Localization<TestCatalog>

    var body: some View {
        VStack {
            SaveLabel(builds: interfaceReader)
            SaveLabel(builds: documentReader).environment(document)
        }
        .environment(interface)
    }
}

@MainActor
final class LocalizationTests: XCTestCase {
    override func setUp() async throws {
        Renderer.shared.clearInvalidation()
    }

    override func tearDown() async throws {
        HostBoundary.setLocaleInfo(HostLocaleInfo(
            language: "", region: "", name: "", timeZone: "", uses24HourClock: false, firstDayOfWeek: .sunday,
            isMetric: true, layoutDirection: .leftToRight))
        Renderer.shared.clearInvalidation()
    }

    private var changed: Set<ObjectIdentifier> { Renderer.shared.pendingChanges }

    private func system(_ name: String, languages: [String] = []) {
        let tag = LocaleTag(name)
        HostBoundary.setLocaleInfo(HostLocaleInfo(
            language: tag.language, region: tag.region ?? "", name: name, timeZone: "Europe/Warsaw",
            uses24HourClock: true, firstDayOfWeek: .monday, isMetric: true, layoutDirection: .leftToRight,
            languages: languages))
    }

    // MARK: - Which language

    func testWithNothingSaidTheCatalogsDefaultSpeaks() {
        XCTAssertEqual(Localization(TestCatalog.self).resolvedLanguage, .english)
    }

    func testTheSystemsLanguageSpeaksWhereTheCatalogHasIt() {
        system("pl-PL")

        XCTAssertEqual(Localization(TestCatalog.self).resolvedLanguage, .polish)
    }

    func testTheFirstOfTheUsersLanguagesTheCatalogHasSpeaks() {
        system("de-CH", languages: ["de-CH", "pl-PL", "en-US"])

        XCTAssertEqual(Localization(TestCatalog.self).resolvedLanguage, .polish)
    }

    func testNoneOfTheUsersLanguagesFallsBackToTheDefault() {
        system("de-CH", languages: ["de-CH", "fr-CH"])

        XCTAssertEqual(Localization(TestCatalog.self).resolvedLanguage, .english)
    }

    func testAFixedLanguageWinsOverTheSystems() {
        system("pl-PL")
        let localization = Localization(TestCatalog.self, language: .fixed(.english))

        XCTAssertEqual(localization.resolvedLanguage, .english)
    }

    func testAScriptTellsTwoVariantsOfOneLanguageApart() {
        system("sr-Latn-RS", languages: ["sr-Latn-RS"])
        XCTAssertEqual(Localization(SerbianCatalog.self).resolvedLanguage, .latin)

        system("sr-RS", languages: ["sr-RS"])
        XCTAssertEqual(Localization(SerbianCatalog.self).resolvedLanguage, .cyrillic, "Serbian is Cyrillic unless said")
    }

    // MARK: - Reading a part

    func testAPartComesInTheLanguageOfTheLocalizationAbove() {
        let renders = Renders()
        let localization = Localization(TestCatalog.self, language: .fixed(.polish))

        let patch = renders.render(stack(
            [Provider(builds: Builds(), reader: Builds(), localization: localization).node], id: "root"))

        XCTAssertEqual(patch.child(.auto(1))?.child(.auto(2))?.props["text"], .string("Zapisz"))
    }

    func testAChangeOfLanguageRebuildsTheReaderAndNotTheProvider() {
        let renders = Renders()
        let owner = Builds(), reader = Builds()
        let localization = Localization(TestCatalog.self)
        renders.render(stack([Provider(builds: owner, reader: reader, localization: localization).node], id: "root"))

        localization.language = .fixed(.polish)
        let patch = renders.revisit(changed: changed)

        XCTAssertEqual(owner.count, 1, "the provider passes a reference and reads nothing of it")
        XCTAssertEqual(reader.count, 2)
        XCTAssertEqual(patch.child(.auto(1))?.child(.auto(2))?.props["text"], .string("Zapisz"))
    }

    func testTheSystemsChangeReachesTheReader() {
        let renders = Renders()
        let localization = Localization(TestCatalog.self)
        renders.render(stack(
            [Provider(builds: Builds(), reader: Builds(), localization: localization).node], id: "root"))

        system("pl-PL")
        let patch = renders.revisit(changed: changed)

        XCTAssertEqual(patch.child(.auto(1))?.child(.auto(2))?.props["text"], .string("Zapisz"))
    }

    func testADocumentKeepsItsOwnLanguage() {
        let renders = Renders()
        let interfaceReader = Builds(), documentReader = Builds()
        let interface = Localization(TestCatalog.self)
        let document = Localization(TestCatalog.self, language: .fixed(.polish))
        let view = InterfaceAndDocument(
            interfaceReader: interfaceReader, documentReader: documentReader, interface: interface,
            document: document)
        let first = renders.render(stack([view.node], id: "root"))
        XCTAssertEqual(first.child(.auto(1))?.child(.auto(2))?.props["text"], .string("Save"))
        XCTAssertEqual(first.child(.auto(1))?.child(.auto(3))?.props["text"], .string("Zapisz"))

        interface.language = .fixed(.polish)
        renders.revisit(changed: changed)
        Renderer.shared.clearInvalidation()
        interface.language = .fixed(.english)
        let patch = renders.revisit(changed: changed)

        XCTAssertEqual(interfaceReader.count, 3)
        XCTAssertEqual(documentReader.count, 1, "the document reads its own localization")
        XCTAssertEqual(patch.child(.auto(1))?.child(.auto(2))?.props["text"], .string("Save"))
    }

    // MARK: - A fragment in another language

    func testSpeakingIsOneObjectPerLanguage() {
        let localization = Localization(TestCatalog.self)

        XCTAssertTrue(localization.speaking(.polish) === localization.speaking(.polish))
        XCTAssertFalse(localization.speaking(.polish) === localization.speaking(.english))
        XCTAssertEqual(localization.speaking(.polish).resolvedLanguage, .polish)
    }

    func testAFragmentsFormatsFollowItsBase() {
        let localization = Localization(TestCatalog.self, formatLocale: .fixed("pl-PL"))
        let english = localization.speaking(.english)

        XCTAssertEqual(english.number(12_345), "12\u{A0}345")
        localization.formatLocale = .fixed("en-US")
        XCTAssertEqual(english.number(12_345), "12,345")
    }

    // MARK: - Messages

    func testAMessageIsSaidInTheResolvedLanguage() {
        let english = Localization(TestCatalog.self, language: .fixed(.english), formatLocale: .fixed("en-US"))
        let polish = Localization(TestCatalog.self, language: .fixed(.polish), formatLocale: .fixed("pl-PL"))

        XCTAssertEqual(english.text(TestWords.english.files, 22), "22 files")
        XCTAssertEqual(english.text(TestWords.english.files, 1), "1 file")
        XCTAssertEqual(polish.text(TestWords.polish.files, 22), "22 pliki")
        XCTAssertEqual(polish.text(TestWords.polish.files, 12_345), "12\u{A0}345 plików")
    }
}
