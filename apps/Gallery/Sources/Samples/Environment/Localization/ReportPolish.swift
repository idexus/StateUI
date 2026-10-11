import StateUI

// listing: LocalizationSample
extension ReportResources {
    static let polish = ReportResources(
        heading: "Raport folderu",
        prepared: Message { day, context in
            "Sporządzono \(context.date(day, style: .long))"
        },
        fileCount: Message { count, context in
            let number = context.number(count)
            return context.plural(count,
                one: "Folder zawiera \(number) plik.",
                few: "Folder zawiera \(number) pliki.",
                many: "Folder zawiera \(number) plików.",
                other: "Folder zawiera \(number) pliku.")
        },
        recent: "Ostatnio zmienione",
        footer: "Wygenerowano w aplikacji Pliki",
        headingStyle: TextStyleSpec(size: 20, lineHeight: 1.15))
}
// listing: end
