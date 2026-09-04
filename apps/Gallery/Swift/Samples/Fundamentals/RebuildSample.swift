import StateUI

/// What a view answers when it is asked why it is being described.
struct RebuildSample: SampleContent {
    static let id = "rebuilds"
    static let title = "Why a view rebuilds"
    static let summary =
        "`debugInfo()` reads back the view's own name, how many times it has "
        + "been described and which state this description is for. Change one "
        + "value and watch which panels answer."

    @State private var left = 0
    @State private var right = 0

    static let code = """
        @State private var left = 0
        @State private var right = 0

        VStack {
            Button("Change left").onClicked { left += 1 }
            Button("Change right").onClicked { right += 1 }

            // Each panel BORROWS one of the two values, so each reads one
            // piece of state and is described again when that one moves.
            Panel(name: "left", value: $left)
            Panel(name: "right", value: $right)
        }

        private struct Panel: ContentView {
            let name: String
            @Binding var value: Int

            var content: Element {
                VStack {
                    Label("\\(name) is \\(value)")

                    // WHY THIS VIEW IS BEING DESCRIBED, on the screen it is
                    // about: the view's name, how many times, and the state
                    // this one is for.
                    Label(debugInfo())

                    Passenger()
                }
            }
        }

        private struct Passenger: ContentView {
            // Reads nothing at all, so it is only ever described because the
            // view above it was - which is what it says.
            var content: Element {
                Label(debugInfo())
            }
        }
        """

    var example: Element {
        VStack {
            HStack {
                Button("Change left")
                    .onClicked { left += 1 }

                Button("Change right")
                    .onClicked { right += 1 }
            }
            .spacing(8)
            .horizontalOptions(.center)

            // TWO OF THEM, side by side, because the reading is only worth
            // anything against another: one panel answers and the other stands
            // still, and the counts say which.
            RebuildPanel(name: "left", value: $left)

            RebuildPanel(name: "right", value: $right)
        }
        .spacing(12)
    }

    var notes: Element? {
        VStack {
            Label("Every view can say why it is being described. `debugInfo()` "
                + "answers the view's own name, how many times it has been "
                + "described, and which piece of state THIS description is "
                + "for - named by the property the author declared it as.")
                .fontSize(13)
                .textColor(Palette.subtle)

            Label("Change one of the two values. The panel that borrowed it "
                + "names it and its count climbs; the other panel stands still, "
                + "because a render rebuilds only the views whose reads moved.")
                .fontSize(13)
                .textColor(Palette.subtle)

            Label("The small line inside each panel is a view that reads "
                + "nothing at all. It says `with its parent`, which is what "
                + "tells a view that reads a value from one that merely sits "
                + "under a view that does - the rebuild starts at the "
                + "outermost view naming a state, and everything below it "
                + "goes along.")
                .fontSize(13)
                .textColor(Palette.subtle)

            Label("Put it in a `Label` on the screen being worked on. Reading "
                + "it causes no render of its own.")
                .fontSize(13)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}

/// One value, and the reading that says why this panel was described.
private struct RebuildPanel: ContentView {
    let name: String

    @Binding var value: Int

    var content: Element {
        Border {
            VStack {
                Label("\(name) is \(value)")
                    .fontSize(15)
                    .fontAttributes(.bold)
                    .textColor(Palette.text)

                Label(debugInfo())
                    .fontSize(13)
                    .textColor(Palette.accent)

                RebuildPassenger()
            }
            .spacing(4)
            .padding(14, 12)
        }
        .stroke(Palette.outline)
        .strokeThickness(1)
        .strokeShape(.roundRectangle(10))
        .backgroundColor(Palette.raised)
    }
}

/// A view that reads nothing, and is described only because the view above it
/// was.
private struct RebuildPassenger: ContentView {
    var content: Element {
        Label(debugInfo())
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
