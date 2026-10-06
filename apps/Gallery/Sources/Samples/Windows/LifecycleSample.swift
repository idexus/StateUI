import StateUI

/// The native window lifecycle recorded through `WindowSession.phase`.
struct LifecycleSample: SampleContent, ExampleContent {
    // listing: LifecycleSample
    /// The window's log, kept by its gallery window. It is written by `MainPage`
    /// as the window is made and by `WindowPhaseLog` as its phase moves - see
    /// Gallery/WindowLog.swift - and this sample only reads it.
    let log: WindowLog
    // listing: end

    static let id = "lifecycle"
    static let title = "Window lifecycle"
    static let summary = "Watch the native window lifecycle as state."

    static var code: String { Listings.joined("WindowLog", "LifecycleSample") }

    var notes: (any View)? { nil }

    // listing: LifecycleSample
    var body: some View {
        VStack {
            Text("What the window has said so far, newest last:")
                .fontSize(14)
                .textColor(Palette.subtle)

            VStack {
                DebugInfoLabel()

                if log.events.isEmpty {
                    Text("nothing yet - switch away and back")
                        .fontSize(15)
                        .textColor(Palette.subtle)
                }

                ForEach(log.events) { row in
                    Text(row)
                        .fontSize(15)
                }
            }
            .spacing(4)
        }
        .spacing(12)
    }
    // listing: end
}
