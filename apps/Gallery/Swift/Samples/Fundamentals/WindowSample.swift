import StateUI

/// How the window this app is running in was set up.
struct WindowSample: SampleContent {
    static let id = "window"
    static let title = "Window"
    static let summary = "What the application's window is called, where it opens and how big it is."

    static let code = """
        struct GalleryApp: Application {
            func createWindow() -> Window { MainWindow(nav: navigation) }
        }

        struct MainWindow: Window {
            let nav: Navigation

            var title: String? { "StateUI Gallery" }
            var width: Double? { 1100 }
            var height: Double? { 800 }
            var minimumWidth: Double? { 700 }
            var minimumHeight: Double? { 500 }

            var content: Page {
                FlyoutPage(nav.$menuOpen) {
                    MenuPage(nav: nav)
                } detail: {
                    detail()
                }
            }
        }

        // MAUI's own, for comparison:
        //
        //     new Window(new FlyoutPage())
        //     {
        //         Title = "StateUI Gallery",
        //         Width = 1100,
        //         Height = 800,
        //         MinimumWidth = 700,
        //         MinimumHeight = 500,
        //     }
        //
        // x and y are there too - where the window opens on the screen.
        """

    var content: Element {
        VStack {
            // Not a hypothetical: this is the window the reader is looking at.
            Label("The window around this page was described in Swift, in "
                + "Gallery/MainWindow.swift. On a Mac it really did open at "
                + "the size below - drag its edge and it moves; drag it in far "
                + "enough and it stops.")
                .fontSize(14)

            SectionTitle("WHAT THIS WINDOW WAS GIVEN")

            Grid {
                Property(name: "title", value: "StateUI Gallery")

                Property(name: "width", value: "opens this wide")
                    .gridRow(1)

                Property(name: "height", value: "opens this tall")
                    .gridRow(2)

                Property(name: "minimumWidth", value: "no narrower")
                    .gridRow(3)

                Property(name: "minimumHeight", value: "no shorter")
                    .gridRow(4)
            }
            .rowDefinitions(.auto, .auto, .auto, .auto, .auto)
            .rowSpacing(8)

            Label("A window that cannot be resized at all is a maximum equal to "
                + "the minimum - minimumWidth and maximumWidth both 1100.")
                .fontSize(12)
                .textColor(Palette.subtle)

            SectionTitle("WHAT THE MAC NEEDED")

            // Worth the space because it is the one that surprises, and because
            // an author who hits it in plain MAUI will conclude the property is
            // broken - which, on that platform, it is.
            Label("MAUI does not implement Window.Width on Mac Catalyst: "
                + "assigning it changes nothing, in C# as much as here. What "
                + "Catalyst does honour is the size restriction behind "
                + "MaximumWidth, so the host opens the window at the size it "
                + "was given through that and gives the restriction back a "
                + "moment later. Hence a window that opens where you said and "
                + "still resizes.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("x and y have no such route and stay Windows "
                + "properties - macOS places its own windows. And the numbers "
                + "are MAUI's units, not the screen's: Catalyst draws UIKit "
                + "content at 77%, so a width of 1100 measures 847 macOS points.")
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

    var content: Element {
        HStack {
            Label(name)
                .fontSize(13)
                .fontAttributes(.bold)
                .widthRequest(160)

            Label(value)
                .fontSize(13)
                .textColor(Palette.subtle)
                .verticalOptions(.center)
        }
        .spacing(12)
    }
}
