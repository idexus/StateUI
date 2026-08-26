import StateUI

/// MAUI: Window.Created, Activated, Deactivated, Stopped, Resumed, Destroying.
struct LifecycleSample: SampleContent {
    /// The window's log, lent by the application. The handlers are the
    /// WINDOW's - written on `MainWindow`, see Gallery/MainWindow.swift - so
    /// the state lives where the window does and this sample only reads it.
    /// A `Binding` rather than a value: a pushed page is built once per push,
    /// and only a binding keeps reading what the window writes afterwards.
    @Binding var events: [String]

    static let id = "lifecycle"
    static let title = "Window lifecycle"
    static let summary = "Created, activated, stopped, resumed - what the window "
        + "says as the app comes and goes."

    static let code = """
        // The state is the APPLICATION's; the moments are the WINDOW's.
        @State private var windowEvents: [String] = []
        @State private var windowEventCount = 0

        func createWindow() -> Window { MainWindow(note: note) }

        struct MainWindow: Window {
            let note: (String) -> Void

            // MAUI's Window events. created, stopped and resumed are the
            // application's OnStart, OnSleep and OnResume moments; the
            // activated/deactivated pair rides each trip to the background.
            var onCreated: EventHandler? { { note("created") } }
            var onActivated: EventHandler? { { note("activated") } }
            var onDeactivated: EventHandler? { { note("deactivated") } }
            var onStopped: EventHandler? { { note("stopped") } }
            var onResumed: EventHandler? { { note("resumed") } }
            var onDestroying: EventHandler? { { note("destroying") } }

            var content: Page { MainPage() }
        }

        // Numbered, keeping the last six.
        private func note(_ name: String) {
            windowEventCount += 1
            windowEvents = Array(
                (windowEvents + ["\\(windowEventCount) · \\(name)"]).suffix(6))
        }

        // And a page reads the same state:
        VStack {
            ForEach(windowEvents) { row in
                Label(row)
            }
        }
        """

    var content: Element {
        VStack {
            Label("What the window has said so far, newest last:")
                .fontSize(14)
                .textColor(Palette.subtle)

            VStack {
                if events.isEmpty {
                    Label("nothing yet - switch away and back")
                        .fontSize(15)
                        .textColor(Palette.subtle)
                }

                ForEach(events) { row in
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
                + "app says nothing on Mac Catalyst - measured; hide the app "
                + "to see the pair.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The handlers are the WINDOW's, written on MainWindow - "
                + "created, stopped and resumed are MAUI's Application.OnStart, "
                + "OnSleep and OnResume moments, heard on the window because "
                + "that is where MAUI raises them as events. stopped is the "
                + "place to save: nothing promises the process comes back.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
