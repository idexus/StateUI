import StateUI

/// A described state that asks for a render at most so often.
struct PacedStateSample: SampleContent {
    static let id = "paced"
    static let title = "A state on a cadence"
    static let summary =
        "`@State(every: 100)` is an ordinary described state that "
        + "asks for a render at most ten times a second. Drag the slider and "
        + "watch the two counts pull apart."

    /// The ordinary one: every report the slider makes is a render.
    @State private var quick = 0.0

    /// The same value, heard at most ten times a second.
    @State(every: 100) private var paced = 0.0

    static let code = """
        // The same number, held twice, under two different wrappers.
        @State private var quick = 0.0
        @State(every: 100) private var paced = 0.0

        VStack {
            // THE SLIDER HOLDS ITS OWN STATE and writes both of the others,
            // so this body reads NEITHER - and each panel below is rebuilt
            // only by the value it shows, rather than dragged along by the
            // slider's own renders.
            PacedSlider(quick: $quick, paced: $paced)

            PacedPanel(name: "every write", value: $quick)
            PacedPanel(name: "every 100 ms", value: $paced)
        }

        private struct PacedSlider: ContentView {
            @Binding var quick: Double
            @Binding var paced: Double

            @State private var dragged = 0.0

            var content: Element {
                Slider($dragged)
                    .maximum(100)
                    .onValueChanged { quick = $0; paced = $0 }
            }
        }

        private struct PacedPanel: ContentView {
            let name: String
            @Binding var value: Double

            var content: Element {
                VStack {
                    Label("\\(name) — \\(Int(value))")

                    // A RUN OF VIEWS, not a number in a label: what a cadence
                    // is worth is measured in the subtree a change rebuilds.
                    HStack {
                        ForEach(Array(0 ..< Int(value / 10)), id: \\.self) { _ in
                            BoxView().widthRequest(14).heightRequest(14)
                        }
                    }

                    Label(debugInfo())
                }
            }
        }
        """

    var example: Element {
        VStack {
            // THE SLIDER HOLDS ITS OWN STATE, so THIS body reads neither of
            // the two values below. Written the other way - the slider bound
            // straight to `quick` - every report rebuilds this view and both
            // panels ride along, and the paced one then shows the HIGHER
            // count: 57 of somebody else's builds plus 15 of its own.
            // Measured, and it says the opposite of what the sample is about.
            PacedSlider(quick: $quick, paced: $paced)

            // TWO PANELS SIDE BY SIDE over one input: the reports are
            // identical and the wrapper is the only difference, so the counts
            // are a measurement rather than an illustration.
            PacedPanel(name: "every write", value: $quick)

            PacedPanel(name: "every 100 ms", value: $paced)
        }
        .spacing(12)
    }

    var notes: Element? {
        VStack {
            Label("A `@State` is described: writing one asks for a render that "
                + "rebuilds the views that read it. `@State(every: 100)` is "
                + "the same state with a cadence on it - it asks for a render "
                + "at most once every 100 ms.")
                .fontSize(13)
                .textColor(Palette.subtle)

            Label("Drag the slider. Both panels are given the same reports; "
                + "the top one is described on every one of them and the "
                + "bottom one ten times a second. The readings inside each "
                + "panel say how many times it has been built, and which "
                + "value the last build was for.")
                .fontSize(13)
                .textColor(Palette.subtle)

            Label("The window is not a delay the reader waits out. The value "
                + "is written where it is read at once, a render somebody "
                + "else asks for happens on time and shows it, and the last "
                + "write inside a window still gets a render of its own when "
                + "the window ends - let go of the slider and the bottom "
                + "panel catches up.")
                .fontSize(13)
                .textColor(Palette.subtle)

            Label("It is for a value that decides WHICH VIEWS THERE ARE and "
                + "arrives faster than a reader can see - a measurement a page "
                + "settles over, a count a drag runs through. A value that is "
                + "only SHOWN wants `@Bus` and a driven text "
                + "instead, which costs no render at all.")
                .fontSize(13)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}

/// The one input, holding its own state so that neither value below is read by
/// the view that owns the panels.
private struct PacedSlider: ContentView {
    @Binding var quick: Double

    @Binding var paced: Double

    /// What the slider itself shows. Read HERE and nowhere else, so a drag
    /// rebuilds this view alone.
    @State private var dragged = 0.0

    var content: Element {
        Slider($dragged)
            .maximum(100)
            .onValueChanged { value in
                quick = value
                paced = value
            }
    }
}

/// One of the two panels: the value, the run of boxes it decides, and how many
/// times this panel has been described.
private struct PacedPanel: ContentView {
    let name: String

    @Binding var value: Double

    var content: Element {
        Border {
            VStack {
                Label("\(name) — \(Int(value))")
                    .fontSize(15)
                    .fontAttributes(.bold)
                    .textColor(Palette.text)

                // A RUN OF VIEWS rather than a number in a label: what a
                // cadence saves is the subtree a change rebuilds, so the
                // sample shows a subtree.
                HStack {
                    ForEach(Array(0 ..< max(0, Int(value / 10))), id: \.self) { _ in
                        BoxView()
                            .widthRequest(14)
                            .heightRequest(14)
                            .cornerRadius(3)
                            .color(Palette.accent)
                    }
                }
                .spacing(4)
                .heightRequest(14)

                Label(debugInfo())
                    .fontSize(13)
                    .textColor(Palette.accent)
            }
            .spacing(8)
            .padding(14, 12)
        }
        .stroke(Palette.outline)
        .strokeThickness(1)
        .strokeShape(.roundRectangle(10))
        .backgroundColor(Palette.raised)
    }
}
