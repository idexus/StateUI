import StateUI

/// MAUI: TapGestureRecognizer.
struct TapSample: SampleContent {
    @State private var taps = 0

    static let id = "tap"
    static let title = "Tap"
    static let summary = "The whole view answers, not a button inside it."

    // A gesture sample is not put in a scroller: the scroller would claim the
    // drag before the example heard about it. The code below it scrolls
    // instead - see SampleContent.scrolls.
    static let scrolls = false

    static let code = """
        @State private var taps = 0

        VStack {
            Border {
                Label("Tap anywhere on this box")
                    .padding(24)
            }
            .stroke(Palette.accent)
            .strokeShape(.roundRectangle(10))
            .onTapped { taps += 1 }

            Border {
                Label("Double-tap this one to reset")
                    .padding(24)
            }
            .stroke(Palette.outline)
            .strokeShape(.roundRectangle(10))
            .onTapped(numberOfTapsRequired: 2) { taps = 0 }

            Label("Tapped \\(taps) time(s)")
        }
        """

    var content: Element {
        VStack {
            Border {
                Label("Tap anywhere on this box")
                    .fontSize(15)
                    .padding(24)
                    .horizontalTextAlignment(.center)
            }
            .stroke(Palette.accent)
            .strokeThickness(1)
            .strokeShape(.roundRectangle(10))
            .onTapped { taps += 1 }

            Border {
                Label("Double-tap this one to reset")
                    .fontSize(15)
                    .padding(24)
                    .horizontalTextAlignment(.center)
            }
            .stroke(Palette.outline)
            .strokeThickness(1)
            .strokeShape(.roundRectangle(10))
            .onTapped(numberOfTapsRequired: 2) { taps = 0 }

            Label("Tapped \(taps) time(s)")
                .fontSize(17)
                .horizontalTextAlignment(.center)

            Label("This is what a list row is in MAUI: a view with a "
                + "TapGestureRecognizer on it. Every card in this gallery is one.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
