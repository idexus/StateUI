import StateUI

/// MAUI: Window.Created, Activated, Deactivated, Stopped, Resumed, Destroying -
/// as the window's phase, and the log it leaves.
struct LifecycleSample: SampleContent {
    /// The window's log, kept with the gallery. It is written by `MainWindow`,
    /// which watches its window's phase - see Gallery/MainWindow.swift - and
    /// this sample only reads it.
    let log: WindowLog

    static let id = "lifecycle"
    static let title = "Window lifecycle"
    static let summary = "Created, activated, stopped, resumed - what the window "
        + "says as the app comes and goes."

    static let code = """
        // The log is the SCENE's; the moments are the WINDOW's phase.
        final class WindowLog {
            @State var events: [String] = []
            @State private(set) var count = 0

            // Numbered, keeping the last six.
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
                FlyoutPage($menuOpen) { MenuPage() } detail: { HomePage() }
                    // The first moment: .onChanged hears a CHANGE, and the
                    // phase starts at .created.
                    .onCreated { log.note("created") }
                    // Every moment after it.
                    .onChanged(window.phase) { log.note("\\(window.phase)") }
            }
        }

        // And a page reads the same state:
        VStack {
            // The log is read here, so every moment the window reports
            // builds this closure again.
            DebugInfoLabel()

            ForEach(log.events) { row in
                Label(row)
            }
        }
        """

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

    var notes: Element? {
        VStack {
            Label("Send the app to the background and bring it back: "
                + "deactivated then stopped on the way out, resumed then "
                + "activated on the way home - the phone's home button, or "
                + "hiding the app on a Mac. A mere switch of focus to another "
                + "app says nothing on Mac Catalyst; hide the app "
                + "to see the pair.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The log is the WINDOW's phase, watched on MainWindow with "
                + ".onChanged(window.phase), and .onCreated for its first line - the "
                + "phase starts at created, and .onChanged hears a change. stopped is "
                + "the place to save: nothing promises the process comes back. Where "
                + "the application itself stands is application.phase - see the "
                + "Phases sample - and the window's last moment, destroying, closes "
                + "the gallery and this log with it.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
