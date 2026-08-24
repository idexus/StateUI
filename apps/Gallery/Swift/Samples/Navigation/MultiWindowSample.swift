import StateUI

/// MAUI: Application.Windows, and the array this side keeps it in step with.
struct MultiWindowSample: SampleContent {
    /// Where the gallery is. The windows are part of it: opening one is one
    /// more thing this application's navigation model can do.
    let nav: Navigation

    static let id = "multi-window"
    static let title = "More than one window"
    static let summary = "The application's windows are a list, and opening one is an append."

    /// iPad, Mac and Windows. A phone shows one window and refuses the request
    /// for a second, so the sample would be a button that does nothing.
    static let idioms: Set<DeviceIdiom> = [.tablet, .desktop]

    static let code = """
        struct GalleryApp: Application {
            @State private var inspectors: [Int] = []

            func createWindow() -> Window { MainWindow(inspectors: $inspectors) }

            var windows: [Window] {                     // MAUI: Application.Windows
                [createWindow()] + inspectors.map {
                    InspectorWindow(number: $0, inspectors: $inspectors)
                }
            }
        }

        struct InspectorWindow: Window {                // a KIND of window
            let number: Int
            let inspectors: Binding<[Int]>

            var id: AnyHashable? { number }             // WHICH window this is
            var title: String? { "Inspector \\(number)" }
            var width: Double? { 460 }
            var height: Double? { 620 }

            var onDestroying: EventHandler? {           // the reader closed it
                { inspectors.wrappedValue.removeAll { $0 == number } }
            }

            var content: Page {
                InspectorPage(number: number, inspectors: inspectors)
            }
        }

        // -- OPENING AND CLOSING --

        Button("Open a window")
            .onClicked { inspectors.append((inspectors.max() ?? 0) + 1) }

        Button("Close")
            .onClicked { inspectors.removeAll { $0 == number } }

        // -- AND ON APPLE, ONE LINE OF Info.plist --
        //
        // <key>UIApplicationSceneManifest</key>
        // <dict>
        //     <key>UIApplicationSupportsMultipleScenes</key><true/>
        // </dict>
        """

    var content: Element {
        VStack {
            Label("An application's windows are a LIST - `var windows: [Window]`, MAUI's "
                + "own `Application.Windows`. One window is what an application says by "
                + "leaving it alone; several are ordinary Swift over ordinary state, and "
                + "the host opens and closes the platform's windows to match. Opening "
                + "one is `append`, closing it is `remove`: the same protocol as a "
                + "navigation path and a modal stack, one level further out.")
                .fontSize(13)
                .textColor(Palette.subtle)

            SectionTitle("OPEN ONE")

            Button("Open an inspector window")
                .backgroundColor(Palette.accent)
                .textColor(.white)
                .cornerRadius(8)
                .padding(20, 10)
                .horizontalOptions(.center)
                .onClicked { nav.openInspector() }

            Label("It shows where the gallery is, live. Both windows are built from the "
                + "same `@State` in the same render, so walking around in this one "
                + "changes what the other says - with nothing subscribed to anything.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Button("Close every window but this one")
                .fontSize(13)
                .padding(16, 6)
                .horizontalOptions(.center)
                .onClicked { nav.closeExtraWindows() }

            SectionTitle("WHAT IS OPEN")

            if nav.inspectors.isEmpty {
                Label("the main window, and nothing else")
                    .fontSize(13)
                    .fontFamily("Menlo")
                    .textColor(Palette.accent)
            } else {
                VStack {
                    ForEach(nav.inspectors) { number in
                        HStack {
                            Label("Inspector \(number)")
                                .fontSize(13)
                                .fontFamily("Menlo")
                                .textColor(Palette.accent)
                                .verticalOptions(.center)
                                .horizontalOptions(.start)

                            Button("Close")
                                .padding(14, 6)
                                .onClicked { nav.closeInspector(number) }
                        }
                        .spacing(10)
                    }
                }
                .spacing(6)
            }

            Label("Read from the same array the application is built from, so this page "
                + "and the desktop cannot disagree. Close a window with its own title "
                + "bar button and watch this list shorten: `destroying` is the report, "
                + "and the handler written on the window folds it back.")
                .fontSize(12)
                .textColor(Palette.subtle)

            SectionTitle("TWO THINGS ARE YOURS").warns(true)

            Label("`.id(number)` says WHICH window this is. Without it a window is "
                + "identified by its place in the list, and closing the middle one of "
                + "three moves the last one's page into it. And `onDestroying` is what "
                + "puts a window the READER closed back into your state - the library "
                + "cannot fold that away for you, because the list is yours. Write it as "
                + "a removal by value and it stays right from both ends.")
                .fontSize(12)
                .textColor(Palette.subtle)

            SectionTitle("AND THE PLATFORM MAY ASK TOO")

            Label("A Mac offers a window of its own as `File ▸ New Window`, an iPad as "
                + "its window controls. That request reaches the APPLICATION as "
                + "`onCreatingWindow`, and the gallery answers it with one more "
                + "document - the same `append` this page's button makes, because by "
                + "the time either reaches `windows` there is nothing to tell apart. "
                + "Try it there: the window that opens is a page written in Swift like "
                + "any other, reading this very state.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Windows never asks, so the handler is never called there: the app "
                + "is asked for its window once, at launch, and opening it again from "
                + "the taskbar starts a second PROCESS with a tree of its own. The "
                + "button above is the whole of multi-window on that platform, and it "
                + "is enough.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("An application that leaves `onCreatingWindow` unwritten shows the "
                + "windows it lists, and the platform's window is closed again. That "
                + "is the honest answer to a request nothing describes - the reader "
                + "used their own system's gesture and did nothing wrong, so an error "
                + "in their face would be a lie and a blank window would say nothing.")
                .fontSize(12)
                .textColor(Palette.subtle)

            SectionTitle("WHERE A SECOND WINDOW EXISTS")

            Label("iPad, Mac Catalyst and Windows. A phone has one window and always "
                + "will; describing more there is not an error, the extra windows simply "
                + "never open. On iOS and Mac Catalyst the app must also declare "
                + "`UIApplicationSupportsMultipleScenes` in its Info.plist - without it "
                + "the system refuses the request, silently, which is exactly what it "
                + "does on a phone.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("HOW it appears is the platform's, and iPadOS changed its mind about "
                + "that: up to iPadOS 18 a second window opens BESIDE the first, both on "
                + "screen at once, while iPadOS 26 opens it FULL SCREEN and puts the "
                + "first away - so the phase reads `activated` on the one and `stopped` "
                + "on the other, and closing the second there leaves the app showing no "
                + "window at all until it is opened again. Measured on both. Nothing in "
                + "the tree changes for any of it: a window list is a list either way.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
