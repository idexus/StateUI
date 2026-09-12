import StateUI

/// How the window this app is running in was set up - and set up again while
/// it runs.
struct WindowSample: SampleContent {
    /// The window this page is in: what it was called and how big, and what
    /// the buttons below write again.
    @Environment private var window: WindowSession

    /// How many times the window has been renamed from here.
    @State private var renames = 0

    /// The example's own frame, in the window's coordinates - rewritten by
    /// every resize, which is what makes the readout move.
    @State private var width = 0.0
    @State private var height = 0.0

    static let id = "window"
    static let title = "Window"
    static let summary = "What the window is called and how big it is - said as it opens, "
        + "and again while it runs."

    static let code = """
        struct GalleryScene: Scene {
            @State private var nav = Navigation()

            var windows: Windows {
                Windows {
                    WindowGroup(.fonts) { FontsWindow() }
                } main: {
                    MainWindow(nav: nav)
                }
                .environment(nav)
            }
        }

        struct MainWindow: Window {
            // The window as it runs: its title, its size, its phase.
            @Environment private var window: WindowSession
            let nav: Navigation

            var page: any Page {
                FlyoutPage(nav.$menuOpen) {
                    MenuPage(nav: nav)
                } detail: {
                    detail()
                }
                .onCreated {
                    window.title = "StateUI Gallery"
                    window.width = 1100
                    window.height = 800
                    window.minimumWidth = 700
                    window.minimumHeight = 500

                    // The two controls the chrome carries, which are a
                    // different question from the sizes: a window may be
                    // resizable and still refuse to go full-screen.
                    window.isMaximizable = true
                    window.isMinimizable = true
                }
            }
        }

        // -- AND AGAIN, WHILE IT RUNS --

        // The same session, from a page in the window: written again, the
        // window follows.
        @Environment private var window: WindowSession
        @State private var renames = 0

        Button("Rename it").onClicked {
            renames += 1
            window.title = "Renamed \\(renames)"
        }

        Button("Its own name").onClicked { window.title = "StateUI Gallery" }

        Button("900 × 650").onClicked {
            window.width = 900
            window.height = 650
        }

        Button("1100 × 800").onClicked {
            window.width = 1100
            window.height = 800
        }

        // What this page shows under the table: its own frame, reported as
        // the window lays it out - resize the window and the numbers move.
        @State private var width = 0.0
        @State private var height = 0.0

        VStack {
            // The name and the measurement are read here, so a rename and
            // every frame report build this closure again.
            DebugInfoLabel()

            Label("window.title is \\(window.title ?? "not set")")
            Label("this example measures \\(Int(width)) × \\(Int(height))")
        }
        .onFrameChanged(in: .global) { frame in
            width = frame.width
            height = frame.height
        }
        """

    var content: any View {
        VStack {
            DebugInfoLabel()

            // Not a hypothetical: this is the window the reader is looking at.
            Label("The window around this page was described in Swift, in "
                + "Gallery/MainWindow.swift. On a Mac it really did open at "
                + "the size below - drag its edge and it moves; drag it in far "
                + "enough and it stops.")
                .fontSize(14)

            SectionTitle("WHAT THIS WINDOW WAS GIVEN")

            Grid {
                Property(name: "window.title", value: "StateUI Gallery")

                Property(name: "window.width", value: "1100")
                    .gridRow(1)

                Property(name: "window.height", value: "800")
                    .gridRow(2)

                Property(name: "window.minimumWidth", value: "700 - no narrower")
                    .gridRow(3)

                Property(name: "window.minimumHeight", value: "500 - no shorter")
                    .gridRow(4)

                Property(name: "window.isMaximizable", value: "the maximize control works")
                    .gridRow(5)

                Property(name: "window.isMinimizable", value: "so does minimize")
                    .gridRow(6)
            }
            .rowDefinitions(.auto, .auto, .auto, .auto, .auto, .auto, .auto)
            .rowSpacing(8)

            SectionTitle("AND AGAIN, WHILE IT RUNS")

            HStack {
                action("Rename it") {
                    renames += 1
                    window.title = "Renamed \(renames)"
                }

                action("Its own name") { window.title = "StateUI Gallery" }
            }
            .spacing(10)
            .horizontalOptions(.center)

            HStack {
                action("900 × 650") {
                    window.width = 900
                    window.height = 650
                }

                action("1100 × 800") {
                    window.width = 1100
                    window.height = 800
                }
            }
            .spacing(10)
            .horizontalOptions(.center)

            Label("window.title is \(window.title ?? "not set")")
                .fontSize(13)
                .fontFamily("Menlo")
                .horizontalTextAlignment(.center)

            Label("this example measures \(Int(width)) × \(Int(height)) right now - "
                + "on a desktop, drag the window's edge or press a size above and the "
                + "numbers follow; on a phone the window IS the screen, and all of this "
                + "is the platform's to answer")
                .fontSize(13)
                .textColor(Palette.accent)
                .horizontalTextAlignment(.center)

            Label("A window that cannot be resized at all is a maximum equal to "
                + "the minimum - minimumWidth and maximumWidth both 1100. The two "
                + "controls are a separate answer: `window.isMaximizable = false` "
                + "leaves the button drawn and inert, or takes it away, whichever "
                + "the platform does.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(14)
        .onFrameChanged(in: .global) { frame in
            width = frame.width
            height = frame.height
        }
    }

    /// A button that writes the window's session.
    private func action(_ caption: String, _ write: @escaping () -> Void) -> any View {
        Button(caption)
            .fontSize(13)
            .padding(16, 6)
            .onClicked { write() }
    }

    var notes: Element? {
        VStack {
            Label("A window's title and size are its WindowSession's, in the environment "
                + "of everything in it: state written like any other - once in .onCreated "
                + "as the window opens, and again from any handler, the window following "
                + "each write. The title is what the Window menu and the Dock list the "
                + "window by.")
                .fontSize(12)
                .textColor(Palette.subtle)

            SectionTitle("WHAT THE MAC NEEDED")

            // Worth the space because it is the one that surprises, and because
            // an author who hits it in plain MAUI will conclude the property is
            // broken - which, on that platform, it is.
            Label("MAUI does not implement Window.Width on Mac Catalyst: "
                + "assigning it changes nothing, in C# as much as here. What "
                + "Catalyst does honour is the size restriction behind "
                + "MaximumWidth, so the host brings the window to the size it "
                + "was given through that and gives the restriction back a "
                + "moment later. Hence a window at the size you said that "
                + "still resizes.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("x and y have no such route and stay Windows "
                + "properties - macOS places its own windows. And the numbers "
                + "are MAUI's units, not the screen's: on a Mac the app is drawn "
                + "at 77%, so a width of 1100 measures 847 points on screen.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(14)
    }
}

/// One line of the table above: what was written, and what it does.
private struct Property: ContentView {
    let name: String
    let value: String

    var content: any View {
        HStack {
            Label(name)
                .fontSize(13)
                .fontAttributes(.bold)
                .widthRequest(200)

            Label(value)
                .fontSize(13)
                .textColor(Palette.subtle)
                .verticalOptions(.center)
        }
        .spacing(12)
    }
}
