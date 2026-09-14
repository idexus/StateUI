import StateUI

/// A gallery is a SCENE: its main window, the windows it opens beside it, and
/// the state they share - and another gallery is one more scene.
struct MultiWindowSample: SampleContent, ExampleContent {
    /// This gallery's look, which its Fonts and Colours windows change.
    let style: SessionStyle

    /// This gallery as it runs: where it stands, and opening and closing its
    /// windows - and itself.
    @Environment private var scene: SceneSession

    /// The application as it runs - which is what opens another gallery.
    @Environment private var application: ApplicationSession

    /// What the last button answered: the window it opened or closed, or what
    /// it was refused with.
    @State private var said = "Nothing asked yet."

    static let id = "multi-window"
    static let title = "More than one window"
    static let summary = "Open tools, valued windows, and another independent scene."

    /// Devices whose host can present independent windows.
    static let formFactors: Set<FormFactor> = [.tablet, .desktop]

    static let code = """
        extension WindowType {
            static let fonts = WindowType("gallery.fonts")
            static let colours = WindowType("gallery.colours")
            static let swatch = WindowType("gallery.swatch")
        }

        extension SceneKey {
            static let font = SceneKey("gallery.font", of: String.self)
            static let accent = SceneKey("gallery.accent", of: AccentChoice.self)
        }

        enum AccentChoice: String, CaseIterable, PersistentValue { case violet, teal, coral, graphite }

        struct GalleryApp: Application {
            var scene: any Scene { GalleryScene() }         // a gallery, and as many more
        }

        struct GalleryScene: Scene {                    // ONE gallery
            @State private var style = SessionStyle()   // this gallery's own

            var windows: Windows {
                Windows {
                    WindowGroup(.fonts) { FontsWindow() }
                        .hidesWhenInactive(style.hidesTools)
                        .floatsOnTop(style.floatsTools)
                    WindowGroup(.colours) { ColoursWindow() }
                        .hidesWhenInactive(style.hidesTools)
                        .floatsOnTop(style.floatsTools)
                    WindowGroup(.debugInspector) { DebugInspector() }
                    WindowGroup(.swatch, for: Int.self) { number in     // one per value,
                        SwatchWindow(number: number)                    // its value lent
                    }
                } main: {
                    MainWindow(style: style)
                }
                .environment(style)                     // one context for all of them
            }
        }

        final class SessionStyle {                      // kept WITH its gallery
            @State(sceneKey: .font) var font = ""
            @State(sceneKey: .accent) var accent = AccentChoice.violet
            @State var hidesTools = false
            @State var floatsTools = false
        }

        // Opening and closing this gallery's windows:

        let style: SessionStyle
        @Environment private var scene: SceneSession            // THIS gallery
        @Environment private var application: ApplicationSession
        @State private var said = "Nothing asked yet."

        Button("Fonts").onClicked {
            do {
                try await scene.openWindow(.fonts)
            } catch WindowError.alreadyOpen {
                said = "It is open already."
            }
        }

        Button("Close fonts").onClicked { try await scene.closeWindow(.fonts) }

        SwitchRow("Hide them behind another gallery", style.$hidesTools)
        SwitchRow("Keep them on top", style.$floatsTools)

        // And a window closes itself, from a page in it:
        //     @Environment private var window: WindowSession
        //     Button("Done").onClicked { try await window.close() }

        // A window per value:

        Button("Swatch 2").onClicked { try await scene.openWindow(.swatch, value: 2) }
        Button("Close swatch 2").onClicked { try await scene.closeWindow(.swatch, value: 2) }

        // Each window is handed its number as a binding - writing it makes the
        // SAME window about another swatch, in SwatchWindow.swift:
        //     Button("Next").onClicked { number += 1 }

        // Another gallery:

        Button("Open another gallery").onClicked { try await application.openScene() }
        Button("Close this gallery").onClicked { try await scene.close() }

        VStack {
            // What the last button answered, and what is open - read here, so
            // a gallery or a window opening or closing builds this closure.
            DebugInfoLabel()
            Label(said)
            Label("\\(application.scenes.count) galleries open")
            Label(scene.windows.map { $0.title ?? "untitled" }.joined(separator: " · "))
        }
        """

    var content: any View {
        VStack {
            preview

            SectionTitle("This gallery's windows")

            HStack {
                opens("Fonts", .fonts)
                opens("Colours", .colours)
            }
            .spacing(10)
            .horizontalAlignment(.center)

            HStack {
                closes("Close fonts", .fonts)
                closes("Close colours", .colours)
            }
            .spacing(10)
            .horizontalAlignment(.center)

            VStack {
                DebugInfoLabel()

                Label(said)
                    .fontSize(13)
                    .fontFamily("Menlo")
                    .textColor(Palette.accent)
                    .horizontalTextAlignment(.center)

                Label(application.scenes.count == 1
                    ? "1 gallery open"
                    : "\(application.scenes.count) galleries open")
                    .fontSize(13)
                    .horizontalTextAlignment(.center)

                Label("this gallery's windows: "
                    + scene.windows.map { $0.title ?? "untitled" }.joined(separator: " · "))
                    .fontSize(13)
                    .textColor(Palette.subtle)
                    .horizontalTextAlignment(.center)
            }
            .spacing(4)

            SwitchRow("Hide them behind another gallery", style.$hidesTools)
            SwitchRow("Keep them on top", style.$floatsTools)

            SectionTitle("A window per value")

            HStack {
                swatch(1)
                swatch(2)
                swatch(3)
            }
            .spacing(10)
            .horizontalAlignment(.center)

            Button("Close swatch 2")
                .fontSize(13)
                .padding(14, 6)
                .horizontalAlignment(.center)
                .onClicked { await closeSwatch(2) }

            SectionTitle("Another gallery")

            Button("Open another gallery")
                .background(style.accent.color)
                .textColor(.white)
                .cornerRadius(8)
                .padding(20, 10)
                .horizontalAlignment(.center)
                .automationId("scene.open")
                .onClicked { await openAnother() }

            Button("Close this gallery")
                .fontSize(13)
                .padding(14, 6)
                .horizontalAlignment(.center)
                .automationId("scene.close")
                .onClicked { await closeThis() }
        }
        .spacing(12)
    }

    var notes: Element? {
        Label("Fonts and Colours are this gallery's own windows: they change its font "
            + "and accent, and close with it. A swatch window exists once per value, "
            + "its number lent to it as a binding. Another gallery is one more scene, "
            + "with windows and state of its own.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }

    /// A line in the gallery's own font and accent - what its two windows
    /// change.
    private var preview: any View {
        let line = Label("The quick brown fox jumps over the lazy dog.")
            .fontSize(20)
            .textColor(style.accent.color)
            .horizontalTextAlignment(.center)

        return style.font.isEmpty ? line : line.fontFamily(style.font)
    }

    /// The button that opens one of the gallery's windows.
    private func opens(_ caption: String, _ type: WindowType) -> any View {
        Button(caption)
            .background(style.accent.color)
            .textColor(.white)
            .cornerRadius(8)
            .padding(20, 8)
            .automationId(handle("window.open", caption))
            .onClicked { await open(type, caption) }
    }

    /// The button that closes it.
    private func closes(_ caption: String, _ type: WindowType) -> any View {
        Button(caption)
            .fontSize(13)
            .padding(14, 6)
            .automationId(handle("window.close", caption))
            .onClicked { await close(type, caption) }
    }

    /// Opens a window of this gallery, and says what came of it.
    private func open(_ type: WindowType, _ caption: String) async {
        do {
            try await scene.openWindow(type)
            said = "\(caption): opened."
        } catch WindowError.alreadyOpen {
            said = "\(caption): WindowError.alreadyOpen - it is open already."
        } catch {
            said = "\(caption): \(error)"
        }
    }

    /// Closes one, and says what came of it.
    private func close(_ type: WindowType, _ caption: String) async {
        do {
            try await scene.closeWindow(type)
            said = "\(caption): closed."
        } catch WindowError.notOpen {
            said = "\(caption): WindowError.notOpen - it is not open."
        } catch {
            said = "\(caption): \(error)"
        }
    }

    /// Opens another gallery.
    private func openAnother() async {
        do {
            try await application.openScene()
            said = "Another gallery is open."
        } catch {
            said = "Another gallery: \(error)"
        }
    }

    /// The button that opens one swatch's window.
    private func swatch(_ number: Int) -> any View {
        Button("Swatch \(number)")
            .background(SwatchPage.colour(of: number))
            .textColor(.white)
            .cornerRadius(8)
            .padding(16, 8)
            .automationId("window.open.swatch.\(number)")
            .onClicked { await openSwatch(number) }
    }

    /// Opens a swatch's window, and says what came of it.
    private func openSwatch(_ number: Int) async {
        do {
            try await scene.openWindow(.swatch, value: number)
            said = "Swatch \(number): opened."
        } catch WindowError.alreadyOpen {
            said = "Swatch \(number): WindowError.alreadyOpen - it is open already."
        } catch {
            said = "Swatch \(number): \(error)"
        }
    }

    /// Closes one, and says what came of it.
    private func closeSwatch(_ number: Int) async {
        do {
            try await scene.closeWindow(.swatch, value: number)
            said = "Swatch \(number): closed."
        } catch WindowError.notOpen {
            said = "Swatch \(number): WindowError.notOpen - it is not open."
        } catch {
            said = "Swatch \(number): \(error)"
        }
    }

    /// Ends this gallery - its main window and every window it opened.
    private func closeThis() async {
        do {
            try await scene.close()
        } catch {
            said = "This gallery: \(error)"
        }
    }

}
