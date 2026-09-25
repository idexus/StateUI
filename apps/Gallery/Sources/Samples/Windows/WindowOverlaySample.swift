import StateUI

extension OverlayKey {
    /// The sample's notice.
    static let notice = OverlayKey("notice")
}

/// A notice the window lays over every page, which stays while the pages change under it.
struct WindowOverlaySample: SampleContent, ExampleContent {
    @Environment private var window: WindowSession

    @State private var shown = false

    static let id = "windowOverlay"
    static let title = "Window overlay"
    static let summary = "Lay a notice over the window, then open another page."

    static let code = """
        extension OverlayKey {
            static let notice = OverlayKey("notice")
        }

        @Environment private var window: WindowSession
        @State private var shown = false

        Switch($shown).onChanged(shown) {
            window.overlays[.notice] = shown ? WindowNotice() : nil
        }

        struct WindowNotice: ContentView {
            @Environment private var window: WindowSession

            var content: any View {
                HStack {
                    Label("Over every page")
                    Button("Dismiss").onClicked { window.overlays[.notice] = nil }
                }
                .horizontalAlignment(.center)
                .verticalAlignment(.start)
            }
        }
        """

    var notes: Element? { nil }

    var content: any View {
        HStack {
            Switch($shown)
                .accessibilityIdentifier("window.overlay")
                .accessibilityLabel("Notice over the window")
            Label("Notice over the window").verticalAlignment(.center)
        }
        .spacing(8)
        .onChanged(shown) {
            guard shown != (window.overlays[.notice] != nil) else { return }
            window.overlays[.notice] = shown ? WindowNotice() : nil
        }
        // The switch follows the notice, which its own button takes away.
        .onChanged(window.overlays[.notice] != nil) { shown = window.overlays[.notice] != nil }
        .onCreated { shown = window.overlays[.notice] != nil }
    }
}

/// What the sample lays over the window: a line at the top, with its own way out.
private struct WindowNotice: ContentView {
    @Environment private var window: WindowSession

    var content: any View {
        HStack {
            Label("Over every page")
                .textColor(.white)
                .verticalAlignment(.center)
            Button("Dismiss")
                .accessibilityIdentifier("window.overlay.dismiss")
                .onClicked { window.overlays[.notice] = nil }
        }
        .spacing(12)
        .padding(16, 8)
        .background(Palette.accent)
        .shape(.roundedRectangle(10))
        .margin(12)
        .horizontalAlignment(.center)
        .verticalAlignment(.start)
    }
}
