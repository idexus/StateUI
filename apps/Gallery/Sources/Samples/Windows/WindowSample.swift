import StateUI

/// Native window identity, geometry, constraints, operations and translucency.
struct WindowSample: SampleContent, ExampleContent {
    // listing: WindowSample
    @Environment(\.window) private var window

    @State private var renames = 0
    @State private var maximizable = true
    @State private var minimizable = true
    @State private var translucent = false
    @State private var width = 0.0
    @State private var height = 0.0
    // listing: end

    static let id = "window"
    static let title = "Window"
    static let summary = "Change the native window while it stays on screen."

    static var code: String { Listings.joined("MainPage.created", "WindowSample") }

    var notes: (any View)? {
        Text("On an iPad and a phone the system sizes and places a window - the user drags its corner - "
            + "so the size, the place, maximizing, minimizing and translucency do nothing there.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }

    // listing: WindowSample
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
                    window.backdrop = translucent ? .material(.regular) : nil
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
        .onCreated { translucent = window.backdrop != nil }
    }

    /// An action that writes the surrounding window session.
    private func action(_ title: String, _ write: @escaping () -> Void) -> some View {
        Button(title)
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
    // listing: end
}
