import StateUI

/// Native window identity, geometry, constraints, and operations.
struct WindowSample: SampleContent {
    @Environment private var window: WindowSession

    @State private var renames = 0
    @State private var maximizable = true
    @State private var minimizable = true
    @State private var width = 0.0
    @State private var height = 0.0

    static let id = "window"
    static let title = "Window"
    static let summary = "Change the native window while it stays on screen."

    static let code = """
        struct MainWindow: Window {
            @Environment private var window: WindowSession

            var page: any View {
                HomePage()
                    .onCreated {
                        window.title = "Notes"
                        window.width = 1100
                        window.height = 800
                        window.minimumWidth = 700
                        window.minimumHeight = 500
                        window.maximumWidth = 1600
                        window.maximumHeight = 1200
                        window.isMaximizable = true
                        window.isMinimizable = true
                    }
            }
        }

        @Environment private var window: WindowSession
        @State private var maximizable = true
        @State private var minimizable = true

        DebugInfoLabel()

        Button("Move to 80, 80").onClicked {
            window.x = 80
            window.y = 80
        }

        Button("900 × 650").onClicked {
            window.width = 900
            window.height = 650
        }

        Switch($maximizable).onChanged(maximizable) {
            window.isMaximizable = maximizable
        }

        Switch($minimizable).onChanged(minimizable) {
            window.isMinimizable = minimizable
        }
        """

    var content: any View {
        VStack {
            DebugInfoLabel()

            Label(window.title ?? "Platform title")
                .fontSize(15)
                .fontAttributes(.bold)

            HStack {
                action("Rename") {
                    renames += 1
                    window.title = "Gallery \(renames)"
                }
                .automationId("window.rename")

                action("Move to 80, 80") {
                    window.x = 80
                    window.y = 80
                }
                .automationId("window.move")
            }
            .spacing(10)

            HStack {
                action("900 × 650") {
                    window.width = 900
                    window.height = 650
                }
                .automationId("window.compact")

                action("1100 × 800") {
                    window.width = 1100
                    window.height = 800
                }
                .automationId("window.regular")
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

            Label("Sample frame: \(Int(width)) × \(Int(height))")
                .fontSize(13)
                .textColor(Palette.accent)
        }
        .spacing(12)
        .onFrameChanged(in: .global) { frame in
            width = frame.width
            height = frame.height
        }
    }

    /// An action that writes the surrounding window session.
    private func action(_ title: String, _ write: @escaping () -> Void) -> any View {
        Button(title)
            .fontSize(13)
            .padding(16, 6)
            .onClicked { write() }
    }

    /// A native boolean window capability.
    private func option(_ title: String, id: String, value: Binding<Bool>) -> any View {
        HStack {
            Switch(value)
                .automationId(id)
                .semanticDescription(title)
            Label(title).verticalOptions(.center)
        }
        .spacing(8)
    }
}
