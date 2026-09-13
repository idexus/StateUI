import StateUI

/// What a gallery's window chrome says: the line after its name, and whether
/// it carries the "Surprise me" button. Kept by the gallery's scene and handed
/// to the window that draws the bar and to the sample that writes it - so each
/// gallery's bar says its own, with nothing passed between the two.
final class TitleBarState {
    /// The line after the title in the window's chrome. Empty hides it.
    @State var subtitle = ""

    /// Whether the bar carries its trailing "Surprise me" button.
    @State var showsSurprise = false
}

/// MAUI: TitleBar - the window's own chrome, desktop only.
struct TitleBarSample: SampleContent {
    /// For the caption's last line: which kind of device this page is
    /// actually on, from the standard environment.
    @Environment var device: DeviceInfo

    /// What this gallery's chrome says - written here, drawn by its window.
    let bar: TitleBarState

    static let id = "titleBar"
    static let title = "TitleBar"
    static let summary = "The window's own chrome - a subtitle and a button "
        + "in the strip that drags the window."

    /// Desktop only: `WindowHandler.MapTitleBar` has a body on Mac Catalyst
    /// and Windows and nowhere else - measured - so a phone's gallery does not
    /// list a page about chrome it cannot draw.
    static let idioms: Set<DeviceIdiom> = [.desktop]

    static let code = """
        // -- THE WINDOW --
        struct MainWindow: Window {
            @Environment var device: DeviceInfo
            let style: SessionStyle
            let bar: TitleBarState

            @Environment private var window: WindowSession

            var page: any Page {
                flyout
                    // Only a desktop has a window to dress - MAUI draws a
                    // TitleBar on Mac Catalyst and Windows and nowhere else.
                    .onCreated {
                        if device.idiom == .desktop { window.titleBar = chrome }
                    }
                    // Painted in the accent, so written again when it moves.
                    .onChanged(style.accent.color) {
                        if device.idiom == .desktop { window.titleBar = chrome }
                    }
            }

            // The look lives in the SLOTS: MAUI's own .title/.subtitle/.icon
            // draw at the system's size, while a slot is an ordinary view.
            var chrome: TitleBar {
                TitleBar()
                    .backgroundColor(style.accent.color)
                    .trailingContent {
                        ChromeEnd(bar: bar, surprise: { surprise() })
                    }
            }
        }

        // A view of its own, so it reads the sample's state as it builds -
        // the bar around it is written once.
        struct ChromeEnd: ContentView {
            let bar: TitleBarState
            let surprise: EventHandler

            var content: any View {
                HStack {
                    Image("stateui_mark.png")
                    Label("StateUI")
                    Label(bar.subtitle)

                    if bar.showsSurprise {
                        Button("Surprise me")
                            .imageSource("nav_surprise_chrome.png")
                            .contentLayout(.left, spacing: 5)
                            .style("ChromeChip")
                            .onClicked { try await surprise() }
                    }
                }
            }
        }

        // -- THE SAMPLE --
        final class TitleBarState {             // kept by the gallery's scene
            @State var subtitle = ""
            @State var showsSurprise = false
        }

        let bar: TitleBarState                  // the one its window reads

        VStack {
            // The field and the switch are handed the model's own states and
            // read nothing - so typing builds ChromeEnd, in the window's bar,
            // which reads `subtitle`, and not this closure.
            DebugInfoLabel()

            Entry(bar.$subtitle)
                .placeholder("Type a subtitle for the window")

            HStack {
                Switch(bar.$showsSurprise)

                Label("a Surprise me button in the chrome")
            }
        }
        """

    var content: any View {
        VStack {
            DebugInfoLabel()

            Label("The strip across the top of this window is MAUI's TitleBar, "
                + "described in Swift on the WINDOW - written into its session "
                + "- not on any page. Type below and watch the chrome follow.")
                .fontSize(14)

            Entry(bar.$subtitle)
                .automationId("titleBar.subtitle")
                .semanticDescription("Subtitle for the window")
                .placeholder("Type a subtitle for the window")

            HStack {
                Switch(bar.$showsSurprise)
                    .automationId("titleBar.surprise")
                    .semanticDescription("A Surprise me button in the chrome")

                Label("a \"Surprise me\" button in the chrome")
                    .verticalOptions(.center)
            }
            .spacing(8)

            Label("The bar itself drags the window. A view put in one of its "
                + "three slots - leadingContent, content, trailingContent - is "
                + "registered as a passthrough element and takes the click "
                + "instead, which is what makes the button up there a button.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Desktop only: WindowHandler.MapTitleBar has a body on Mac "
                + "Catalyst and Windows and nowhere else, so this sample is "
                + "listed only where the environment's DeviceInfo answers "
                + ".desktop - here it answers: \(device.idiom).")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
