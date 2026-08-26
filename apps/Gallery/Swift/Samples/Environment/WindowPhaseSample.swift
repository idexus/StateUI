import StateUI

/// The window's lifecycle as STATE - where things stand, where the Lifecycle
/// sample shows the same six moments as EVENTS.
struct WindowPhaseSample: SampleContent {
    /// The window's phase, kept current by the host's own lifecycle events.
    @Environment var window: WindowInfo

    static let id = "windowPhase"
    static let title = "Window phase"
    static let summary = "Activated, deactivated or stopped - the lifecycle "
        + "as a value any view can read."

    static let code = """
        struct PhaseBadge: ContentView {
            @Environment var window: WindowInfo

            var content: Element {
                VStack {
                    Label("phase · \\(window.phase)")

                    // A view that should do less while nobody looks reads
                    // the phase; something that must REACT to the moment
                    // itself is the event modifiers - .onActivated,
                    // .onStopped - on the Window.
                    Label(window.phase == .activated
                        ? "someone is looking"
                        : "resting")
                }
            }
        }
        """

    var content: Element {
        VStack {
            Label("\(window.phase)")
                .fontSize(34)
                .fontAttributes(.bold)
                .horizontalTextAlignment(.center)

            Label(window.phase == .activated
                ? "someone is looking"
                : "nobody is looking - a good moment to do less")
                .fontSize(15)
                .horizontalTextAlignment(.center)
        }
        .spacing(10)
    }

    var notes: Element? {
        VStack {
            Label("The same lifecycle two ways: the six Window modifiers - "
                + ".onCreated through .onDestroying, the Lifecycle sample's "
                + "log - answer the MOMENT, and this answers where things "
                + "STAND, without a flag of your own to maintain.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("WHEN it moves is the platform's: an Android phone says "
                + "deactivated then stopped on every trip through the home "
                + "screen, while Mac Catalyst raises nothing on a mere focus "
                + "switch and moves only around hiding and showing the app - "
                + "measured, both. So on a Mac this page usually just says "
                + "activated; hide the app and bring it back to see the rest "
                + "land in the Lifecycle sample's log.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(10)
    }
}
