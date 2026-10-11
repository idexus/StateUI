import StateUI

// listing: LocalizationSample
/// A base typeface: its size and its line height. The user's text size still scales it.
struct TextStyleSpec {
    let size: Double
    let lineHeight: Double
}

/// What the folder report says - the document's own words, a part of its own.
struct ReportResources: LocalizedResources {
    typealias Catalog = ReportCatalog

    let heading: String
    let prepared: Message<CalendarDate>
    let fileCount: Message<Int>
    let recent: String
    let footer: String
    let headingStyle: TextStyleSpec

    static func resources(for language: ReportLanguage) -> ReportResources {
        switch language {
        case .english: .english
        case .polish: .polish
        }
    }
}
// listing: end
