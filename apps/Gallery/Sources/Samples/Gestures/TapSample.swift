import StateUI

/// A tap and a double tap on a whole view.
struct TapSample: SampleContent, ExampleContent {
    @State private var taps = 0

    static let id = "tap"
    static let title = "Tap"
    static let summary = "The whole view answers, not a button inside it."

    // A gesture sample is not put in a scroller: a scroller would claim the
    // drag before the example heard about it, so the page holds the example
    // still - see SampleContent.scrolls.
    static let scrolls = false

    static let code = """
        @State private var taps = 0

        VStack {
            // The count is read here, so every tap builds this closure.
            DebugInfoLabel()

            Border {
                Label("Tap anywhere on this box")
                    .padding(24)
            }
            .stroke(Palette.accent)
            .shape(.roundedRectangle(10))
            .onTapped { taps += 1 }

            Border {
                Label("Double-tap this one to reset")
                    .padding(24)
            }
            .stroke(Palette.outline)
            .shape(.roundedRectangle(10))
            .onTapped(numberOfTapsRequired: 2) { taps = 0 }

            Label("Tapped \\(taps) time(s)")
        }
        """

    var content: any View {
        VStack {
            DebugInfoLabel()

            Border {
                Label("Tap anywhere on this box")
                    .fontSize(15)
                    .padding(24)
                    .horizontalTextAlignment(.center)
            }
            .stroke(Palette.accent)
            .strokeWidth(1)
            .shape(.roundedRectangle(10))
            .onTapped { taps += 1 }

            Border {
                Label("Double-tap this one to reset")
                    .fontSize(15)
                    .padding(24)
                    .horizontalTextAlignment(.center)
            }
            .stroke(Palette.outline)
            .strokeWidth(1)
            .shape(.roundedRectangle(10))
            .onTapped(numberOfTapsRequired: 2) { taps = 0 }

            Label("Tapped \(taps) time(s)")
                .fontSize(17)
                .horizontalTextAlignment(.center)
        }
        .spacing(12)
    }

    var notes: Element? {
        Label("Any view answers a tap: every card on a group's page is a view with "
            + "`.onTapped` on it.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
