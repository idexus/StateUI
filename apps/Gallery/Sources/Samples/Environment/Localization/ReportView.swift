import StateUI

// listing: LocalizationSample
/// A file the folder holds: data, so it reads the same in every language.
struct FileItem: Hashable {
    let name: String
    let modified: CalendarDate
}

/// The document: every word, plural form and date in it follows the nearest localization.
struct ReportView: View {
    @Environment private var res: ReportResources
    @Environment private var localization: Localization<ReportCatalog>
    let fileCount: Int
    let recent: [FileItem]
    let prepared: CalendarDate

    var body: some View {
        VStack {
            Text(res.heading)
                .fontSize(res.headingStyle.size) // listing: keep
                .lineHeight(res.headingStyle.lineHeight) // listing: keep
                .fontAttributes(.bold)
            Text(localization.text(res.prepared, prepared))
            Text(localization.text(res.fileCount, fileCount))

            Text(res.recent)
                .fontAttributes(.bold)
            ForEach(recent) { file in
                HStack {
                    Text(file.name)
                    Text(localization.date(file.modified, style: .medium))
                        .textColor(Palette.subtle)
                }
                .spacing(8)
            }

            Text(res.footer)
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(6)
    }
}
// listing: end
