import StateUI

/// Native window identity, geometry, constraints, operations and translucency.
struct WindowSample: SampleContent, ExampleContent {
    @Environment(\.window) private var window

    @State private var renames = 0
    @State private var maximizable = true
    @State private var minimizable = true
    @State private var translucent = false
    @State private var width = 0.0
    @State private var height = 0.0

    static let id = "window"
    static let title = "Window"
    static let summary = "Change the native window while it stays on screen."

    static let code = """
        // Gallery/MainPage.swift - what the window is as it is made: its
        // title, its first size and how far the user may resize it.
        struct MainPage: View {
            let catalog: Catalog
            let nav: Navigation
            let log: WindowLog

            @Environment(\\.window) private var window

            var body: some View {
                SplitView(nav.$menuOpen) {
                    MenuPage(catalog: catalog, nav: nav, log: log, listsHiddenRow: nav.listsHiddenRow)
                } detail: {
                    HomePage(catalog: catalog, nav: nav)
                }
                .onCreated {
                    window.title = "StateUI Gallery"
                    window.width = 1100
                    window.height = 800
                    #if APPKIT
                    window.isTranslucent = true
                    #endif
                    window.minimumWidth = 700
                    window.minimumHeight = 500
                    window.maximumWidth = 1600
                    window.maximumHeight = 1200
                    window.isMaximizable = true
                    window.isMinimizable = true
                }
            }
        }

        @Environment(\\.window) private var window
        @State private var renames = 0
        @State private var maximizable = true
        @State private var minimizable = true
        @State private var translucent = false
        @State private var width = 0.0
        @State private var height = 0.0

        VStack {
            DebugInfoLabel()

            Text(window.title ?? "Platform title")

            HStack {
                Button("Rename").onClicked {
                    renames += 1
                    window.title = "Gallery \\(renames)"
                }
                Button("Move to 80, 80").onClicked {
                    window.x = 80
                    window.y = 80
                }
            }

            HStack {
                Button("900 × 650").onClicked {
                    window.width = 900
                    window.height = 650
                }
                Button("1100 × 800").onClicked {
                    window.width = 1100
                    window.height = 800
                }
            }

            HStack {
                Switch($maximizable)
                Text("Maximize")
            }
            .onChanged(maximizable) { window.isMaximizable = maximizable }

            HStack {
                Switch($minimizable)
                Text("Minimize")
            }
            .onChanged(minimizable) { window.isMinimizable = minimizable }

            HStack {
                Switch($translucent)
                Text("Translucent")
            }
            .onChanged(translucent) { window.isTranslucent = translucent }

            Text("Sample frame: \\(Int(width)) × \\(Int(height))")
        }
        .onFrameChanged(in: .global) { frame in
            width = frame.width
            height = frame.height
        }
        // The switch starts where the window stands.
        .onCreated { translucent = window.isTranslucent == true }
        """

    var notes: (any View)? {
        Text("On an iPad and a phone the system sizes and places a window - the user drags its corner - "
            + "so the size, the place, maximizing, minimizing and translucency do nothing there.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }

    var body: some View {
        VStack {
            DebugInfoLabel()

            Text(window.title ?? "Platform title")
                .fontSize(15)
                .fontAttributes(.bold)

            HStack {
                action("Rename") {
                    renames += 1
                    window.title = "Gallery \(renames)"
                }
                .accessibilityIdentifier("window.rename")

                action("Move to 80, 80") {
                    window.x = 80
                    window.y = 80
                }
                .accessibilityIdentifier("window.move")
            }
            .spacing(10)

            HStack {
                action("900 × 650") {
                    window.width = 900
                    window.height = 650
                }
                .accessibilityIdentifier("window.compact")

                action("1100 × 800") {
                    window.width = 1100
                    window.height = 800
                }
                .accessibilityIdentifier("window.regular")
            }
            .spacing(10)

            option("Maximize", id: "window.maximize", value: $maximizable)
                .onChanged(maximizable) {
                    window.isMaximizable = maximizable
                }

            option("Minimize", id: "window.minimize", value: $minimizable)
                .onChanged(minimizable) {
                    window.isMinimizable = minimizable
                }

            option("Translucent", id: "window.translucent", value: $translucent)
                .onChanged(translucent) {
                    window.isTranslucent = translucent
                }

            Text("Sample frame: \(Int(width)) × \(Int(height))")
                .fontSize(13)
                .textColor(Palette.accent)
        }
        .spacing(12)
        .onFrameChanged(in: .global) { frame in
            width = frame.width
            height = frame.height
        }
        // The switch starts where the window stands - on, where the gallery's
        // window opens translucent.
        .onCreated { translucent = window.isTranslucent == true }
    }

    /// An action that writes the surrounding window session.
    private func action(_ title: String, _ write: @escaping () -> Void) -> some View {
        Button(title)
            .fontSize(13)
            .padding(horizontal: 16, vertical: 6)
            .onClicked { write() }
    }

    /// A native boolean window capability.
    private func option(_ title: String, id: String, value: Binding<Bool>) -> some View {
        HStack {
            Switch(value)
                .accessibilityIdentifier(id)
                .accessibilityLabel(title)
            Text(title).verticalAlignment(.center)
        }
        .spacing(8)
    }
}
