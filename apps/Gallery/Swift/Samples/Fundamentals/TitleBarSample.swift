import StateUI

/// The window chrome's mutable half, shared between the application - which
/// declares the window and its title bar in `MainWindow` - and
/// the sample page that pokes it. A file-scope model rather than a `@State`
/// because BOTH halves read it, and the window is not a view a binding could
/// be threaded down from.
@StateClass
final class TitleBarState {
    /// The line after the title in the window's chrome. Empty hides it.
    var subtitle = ""

    /// Whether the bar carries its trailing "Surprise me" button.
    var showsSurprise = false
}

/// The one instance both halves read. `nonisolated(unsafe)` the way the
/// library marks its own globals: everything that touches it - the sample's
/// handlers, the window build - runs on the one thread MAUI draws on, and
/// Swift's `@MainActor` is the measured trap this library refuses (its queue
/// is never drained on Android or Windows).
nonisolated(unsafe) let titleBarState = TitleBarState()

/// MAUI: TitleBar - the window's own chrome, desktop only.
struct TitleBarSample: SampleContent {
    /// For the caption's last line: which kind of device this page is
    /// actually on, from the standard environment.
    @Environment var device: DeviceInfo

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

            var title: String? { "StateUI Gallery" }
            var content: Page { flyout }

            // Only a desktop has a window to dress - MAUI draws a TitleBar on
            // Mac Catalyst and Windows and nowhere else.
            var titleBar: TitleBar? {
                guard device.idiom == .desktop else { return nil }

                // The look lives in the SLOTS: MAUI's own .title/.subtitle/
                // .icon draw at the system's size, while a slot is an
                // ordinary view - sized, coloured and updated like any other.
                return TitleBar()
                        .backgroundColor(AppColors.violet)
                        .trailingContent {
                            HStack {
                                Image("stateui_mark.png")
                                Label("StateUI")
                                Label(titleBarState.subtitle)

                                if titleBarState.showsSurprise {
                                    Button("Surprise me")
                                        .imageSource("nav_surprise_chrome.png")
                                        .contentLayout(.left, spacing: 5)
                                        .style("ChromeChip")
                                        .onClicked { surprise() }
                                }
                            }
                        }
            }
        }

        // -- THE SAMPLE --
        @StateClass
        final class TitleBarState {
            var subtitle = ""
            var showsSurprise = false
        }

        let titleBarState = TitleBarState()

        VStack {
            Entry(Binding(
                get: { titleBarState.subtitle },
                set: { titleBarState.subtitle = $0 }))
                .placeholder("Type a subtitle for the window")

            HStack {
                Switch(Binding(
                    get: { titleBarState.showsSurprise },
                    set: { titleBarState.showsSurprise = $0 }))

                Label("a Surprise me button in the chrome")
            }
        }
        """

    var example: Element {
        VStack {
            Label("The strip across the top of this window is MAUI's TitleBar, "
                + "described in Swift on the WINDOW - a titleBar property "
                + "- not on any page. Type below and watch the chrome follow.")
                .fontSize(14)

            Entry(Binding(
                get: { titleBarState.subtitle },
                set: { titleBarState.subtitle = $0 }))
                .placeholder("Type a subtitle for the window")

            HStack {
                Switch(Binding(
                    get: { titleBarState.showsSurprise },
                    set: { titleBarState.showsSurprise = $0 }))

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
