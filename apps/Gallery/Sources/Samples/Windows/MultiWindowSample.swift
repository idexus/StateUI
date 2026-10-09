import StateUI

/// The galleries are a SCENE: as many gallery windows as the user opens, the
/// windows beside them, and the look they share.
struct MultiWindowSample: SampleContent, ExampleContent {
    // listing: MultiWindowSample
    /// The look every gallery window wears, which the Fonts and Colours
    /// windows change.
    let style: SessionStyle

    /// The galleries' scene as it runs: its windows, and closing it whole.
    @Environment(\.scene) private var scene

    /// The application as it runs - which opens a window in the scene
    /// declaring it.
    @Environment(\.application) private var application

    /// What the last button answered: the window it opened or closed, or what
    /// it was refused with.
    @State private var said = "Nothing asked yet."
    // listing: end

    static let id = "multi-window"
    static let title = "More than one window"
    static let summary = "Tools, a window per value, and more gallery windows sharing one scene."

    static var code: String { Listings.joined("Gallery.SessionStyle", "GalleryScene", "GalleryWindow", "MultiWindowSample") }

    /// Devices whose host can present independent windows.
    static let formFactors: Set<FormFactor> = [.tablet, .desktop]

    // listing: MultiWindowSample
    var body: some View {
        VStack {
            preview

            SectionTitle("The scene's windows")

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

                Text(said)
                    .fontSize(13)
                    .fontFamily("Menlo")
                    .textColor(Palette.accent)
                    .horizontalTextAlignment(.center)

                Text("Windows in this scene: \(scene.windows.count)")
                    .fontSize(13)
                    .horizontalTextAlignment(.center)

                Text(scene.windows.map { $0.title ?? "untitled" }.joined(separator: " · "))
                    .fontSize(13)
                    .textColor(Palette.subtle)
                    .horizontalTextAlignment(.center)
            }
            .spacing(4)

            SwitchRow("Hide them behind another scene", style.$hidesTools)
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
                .horizontalAlignment(.center)
                .onClicked(.ignoreWhileRunning) { await closeSwatch(2) }

            SectionTitle("More gallery windows")

            Button("New gallery window")
                .horizontalAlignment(.center)
                .accessibilityIdentifier("scene.open")
                .onClicked(.ignoreWhileRunning) { await openAnother() }

            Button("Close every gallery window")
                .horizontalAlignment(.center)
                .accessibilityIdentifier("scene.close")
                .onClicked(.ignoreWhileRunning) { await closeThis() }
        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? {
        Text("Fonts and Colours are windows of the galleries' scene: they change the "
            + "look every gallery window wears, and close with the scene. A swatch "
            + "window exists once per value, its number lent to it as a binding. "
            + "Another gallery window has a place of its own and the scene's look.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }

    // listing: MultiWindowSample
    /// A line in the scene's font and accent - what its two windows change.
    private var preview: some View {
        let line = Text("The quick brown fox jumps over the lazy dog.")
            .fontSize(20)
            .textColor(style.look(dark: application.info.colorScheme == .dark).barColour.color(system: application.info.accentColor, for: .bar))   // listing: keep
            .horizontalTextAlignment(.center)

        return style.font.isEmpty ? line : line.fontFamily(style.font)
    }

    /// The button that opens one of the scene's windows.
    private func opens(_ caption: String, _ type: WindowType) -> some View {
        Button(caption)
            .accessibilityIdentifier(handle("window.open", caption))
            .onClicked(.ignoreWhileRunning) { await open(type, caption) }
    }

    /// The button that closes it.
    private func closes(_ caption: String, _ type: WindowType) -> some View {
        Button(caption)
            .accessibilityIdentifier(handle("window.close", caption))
            .onClicked(.ignoreWhileRunning) { await close(type, caption) }
    }

    /// Opens a window of the scene, and says what came of it.
    private func open(_ type: WindowType, _ caption: String) async {
        do {
            try await application.openWindow(type)
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
            try await application.closeWindow(type)
            said = "\(caption): closed."
        } catch WindowError.notOpen {
            said = "\(caption): WindowError.notOpen - it is not open."
        } catch {
            said = "\(caption): \(error)"
        }
    }

    /// Opens one more gallery window, as *File ▸ New Window* does.
    private func openAnother() async {
        do {
            try await application.openWindow()
            said = "Another gallery window is open."
        } catch {
            said = "Another gallery window: \(error)"
        }
    }

    /// The button that opens one swatch's window.
    private func swatch(_ number: Int) -> some View {
        Button("Swatch \(number)")
            .background(SwatchPage.colour(of: number))
            .textColor(.white)
            .shape(.roundedRectangle(8))
            .accessibilityIdentifier("window.open.swatch.\(number)")
            .onClicked(.ignoreWhileRunning) { await openSwatch(number) }
    }

    /// Opens a swatch's window, and says what came of it.
    private func openSwatch(_ number: Int) async {
        do {
            try await application.openWindow(.swatch, value: number)
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
            try await application.closeWindow(.swatch, value: number)
            said = "Swatch \(number): closed."
        } catch WindowError.notOpen {
            said = "Swatch \(number): WindowError.notOpen - it is not open."
        } catch {
            said = "Swatch \(number): \(error)"
        }
    }

    /// Ends the scene - every gallery window and every window beside them.
    private func closeThis() async {
        do {
            try await scene.close()
        } catch {
            said = "The scene: \(error)"
        }
    }
    // listing: end
}
