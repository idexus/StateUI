import StateUI

/// The native window lifecycle recorded through `WindowSession.phase`.
struct LifecycleSample: SampleContent, ExampleContent {
    /// The window's log, kept by its gallery window. It is written by `MainPage`
    /// as the window is made and by `WindowPhaseLog` as its phase moves - see
    /// Gallery/WindowLog.swift - and this sample only reads it.
    let log: WindowLog

    static let id = "lifecycle"
    static let title = "Window lifecycle"
    static let summary = "Watch the native window lifecycle as state."

    static let code = """
        // The window's log, kept by its gallery window. MainPage notes
        // "created" in its `.onCreated`.
        final class WindowLog {
            @State var events: [String] = []
            @State private(set) var count = 0

            func note(_ name: String) {
                count += 1
                events = Array((events + ["\\(count) · \\(name)"]).suffix(6))
            }
        }

        // Standing in the menu, which every window shows, it notes each phase.
        struct WindowPhaseLog: View {
            let log: WindowLog

            @Environment(\\.window) private var window

            var body: some View {
                ColorBox(Color("#00000000"))
                    .width(0)
                    .height(0)
                    .ignoresInput(true)
                    .onChanged(window.phase) { log.note("\\(window.phase)") }
            }
        }

        let log: WindowLog

        VStack {
            DebugInfoLabel()

            if log.events.isEmpty {
                Text("nothing yet - switch away and back")
            }

            ForEach(log.events) { row in
                Text(row)
            }
        }
        """

    var notes: (any View)? { nil }

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

}
