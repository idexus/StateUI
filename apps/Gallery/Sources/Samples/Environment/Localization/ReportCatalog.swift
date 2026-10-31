import StateUI

// listing: LocalizationSample
/// The languages the folder report is written in.
enum ReportLanguage: LocaleTag, CaseIterable {
    case english = "en"
    case polish = "pl"
}

/// The report's languages, and the one it falls back to - nothing else, so it never grows.
enum ReportCatalog: LocalizationCatalog {
    static let defaultLanguage = ReportLanguage.english
}
// listing: end
