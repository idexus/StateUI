import StateUI

/// The native window lifecycle recorded through `WindowSession.phase`.
struct LifecycleSample: SampleContent, ExampleContent {
    /// The window's log, kept with the gallery. It is written by `MainWindow`,
    /// which watches its window's phase - see Gallery/MainWindow.swift - and
    /// this sample only reads it.
    let log: WindowLog

    static let id = "lifecycle"
    static let title = "Window lifecycle"
    static let summary = "Watch the native window lifecycle as state."

    static let code = """
        final class WindowLog {
            @State var events: [String] = []
            @State private(set) var count = 0

            func note(_ name: String) {
                count += 1
                events = Array((events + ["\\(count) · \\(name)"]).suffix(6))
            }
        }

        struct MainWindow: Window {
            @Environment private var window: WindowSession
            @State private var menuOpen = false
            let log: WindowLog

            var page: any Page {
                SplitView($menuOpen) { MenuPage() } detail: { HomePage() }
                    .onCreated { log.note("created") }
                    .onChanged(window.phase) { log.note("\\(window.phase)") }
            }
        }

        VStack {
            DebugInfoLabel()

            ForEach(log.events) { row in
                Label(row)
            }
        }
        """

    var notes: Element? { nil }

    var content: any View {
        VStack {
            Label("What the window has said so far, newest last:")
                .fontSize(14)
                .textColor(Palette.subtle)

            VStack {
                DebugInfoLabel()

                if log.events.isEmpty {
                    Label("nothing yet - switch away and back")
                        .fontSize(15)
                        .textColor(Palette.subtle)
                }

                ForEach(log.events) { row in
                    Label(row)
                        .fontSize(15)
                }
            }
            .spacing(4)
        }
        .spacing(12)
    }

}
