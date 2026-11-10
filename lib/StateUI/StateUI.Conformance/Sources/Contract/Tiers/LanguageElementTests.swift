// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `LanguageElementContract` on a host: every element holds the language the tree says on it and the one it changes
/// to; the words under a localization hold the language it speaks, follow its change and stand in their document's
/// own; a window its scene gives a localization holds it in its words.
@_spi(Host) public enum LanguageElementTests: ConformanceFamily {
    public static let name = "LanguageElement"

    public static var cases: [ConformanceCase] {
        Specimens.wearing(VisualElementContract.self).map {
            Aspects.holds(LanguageElementContract.language, on: $0, LocaleTag("pl"), then: LocaleTag("en-GB"))
        } + [underALocalization, aDocumentsOwn, aWindowsScene]
    }

    /// The words under a localization hold the language it speaks, and the one it speaks once the user changes it.
    @MainActor static var underALocalization: ConformanceCase {
        ConformanceCase("theWordsUnderALocalizationHoldItsLanguage", proves: [
            Covered(LanguageElementContract.language, on: TextContract.self),
        ], needs: [Covered(ClickElementContract.clicked, on: ButtonContract.self)]) { s in
            let localization = Localization(ConformanceCatalog.self, language: .polish)
            s.start {
                VStack {
                    Text("Dzień dobry").id("words")
                    Button("English").onClicked { localization.language = .english }.id("change")
                }
                .environment(localization)
            }
            let words = { try s.held(LanguageElementContract.language, on: s.element("words")) }
            try s.settle { try words() == "pl" }
            s.expect(try words(), "pl", "the language the localization speaks")

            try s.perform(.activate, on: s.element("change"))
            try s.settle { try words() == "en" }
            s.expect(try words(), "en", "and the one it speaks once changed")
        }
    }

    /// A document with a localization of its own holds its language under the interface's.
    @MainActor static var aDocumentsOwn: ConformanceCase {
        ConformanceCase("aDocumentsWordsHoldItsOwnLanguage", proves: [
            Covered(LanguageElementContract.language, on: TextContract.self),
        ]) { s in
            s.start {
                VStack {
                    Text("Report").id("interface")
                    VStack { Text("Dzień dobry").id("letter") }
                        .environment(Localization(ConformanceCatalog.self, language: .polish))
                }
                .environment(Localization(ConformanceCatalog.self, language: .english))
            }
            try s.settle { try s.held(LanguageElementContract.language, on: s.element("letter")) == "pl" }
            s.expect(try s.held(LanguageElementContract.language, on: s.element("interface")), "en", "the interface's")
            s.expect(try s.held(LanguageElementContract.language, on: s.element("letter")), "pl", "the document's own")
        }
    }

    /// A window its scene gives a localization holds the language it speaks in its words.
    @MainActor static var aWindowsScene: ConformanceCase {
        ConformanceCase("aWindowsSceneGivesItsWordsTheirLanguage", proves: [
            Covered(LanguageElementContract.language, on: WindowContract.self),
        ]) { s in
            try s.start(application: { SpeakingApplication() })
            try s.settle { try s.held(LanguageElementContract.language, on: s.element("greeting")) == "pl" }
            s.expect(try s.held(LanguageElementContract.language, on: s.element("greeting")), "pl")
        }
    }
}

/// The languages a case's words are written in.
enum ConformanceLanguage: LocaleTag, CaseIterable {
    case english = "en"
    case polish = "pl"
}

/// The catalog a case's localizations speak.
enum ConformanceCatalog: LocalizationCatalog {
    static let defaultLanguage = ConformanceLanguage.english
}

/// An application whose one scene gives its windows a localization speaking Polish.
struct SpeakingApplication: Application {
    var body: some Scene {
        WindowGroup { Text("Dzień dobry").id("greeting") }
            .environment(Localization(ConformanceCatalog.self, language: .polish))
    }
}
