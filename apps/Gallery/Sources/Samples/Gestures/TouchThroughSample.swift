import StateUI

/// Input that goes through a view to the one below - past the view alone, or
/// past its children too.
struct TouchThroughSample: SampleContent, ExampleContent {
    static let id = "touchThrough"
    static let title = "Touch through"
    static let summary = "A layout that lets taps through to what is below, with or without its children."

    /// A gesture sample: a scroller would claim a drag before the example heard
    /// about it, so the page holds the example still.
    static let scrolls = false

    // listing: TouchThroughSample
    @State private var below = 0
    @State private var child = 0
    @State private var childrenToo = false
    @State private var disabled = false

    var body: some View {
        VStack {
            // Both counts are read here, so a tap on either builds this closure.
            DebugInfoLabel()

            Grid {
                // Underneath, and still reachable.
                ColorBox(Palette.accent)
                    .height(120)
                    .onTapped { below += 1 }

                // On top. Its own empty area lets taps through to the box below
                // while the label inside still answers - or, with "Children too",
                // the whole of it ignores input, the label included; disabled,
                // it takes every tap on it and answers none.
                VStack {
                    // The child wears its own colour and its own padding, so
                    // what is the child and what is the empty area around it
                    // can be told apart by eye - and aimed at separately.
                    Text("tap the child")
                        .textColor(Palette.onBrand)
                        .background(Palette.brand)
                        .padding(horizontal: 24, vertical: 12)
                        .horizontalAlignment(.center)
                        .verticalAlignment(.center)
                        .onTapped { child += 1 }
                }
                .padding(16)
                .letsInputThrough(!childrenToo)
                .ignoresInput(childrenToo)
                .isEnabled(!disabled)
            }

            Text("below \(below)   child \(child)")
                .fontSize(13)
                .horizontalAlignment(.center)

            HStack {
                SwitchRow("Children too", $childrenToo)

                SwitchRow("Disabled", $disabled)

                Button("Reset")
                    .onClicked { below = 0; child = 0 }
            }
            .spacing(7)
            .horizontalAlignment(.center)
        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("`letsInputThrough(true)` takes only a layout's own empty area out of "
                + "hit testing: a tap there reaches the box below, and the label inside "
                + "still counts. It is what an overlay over a page wants.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("`ignoresInput(true)` takes the view and everything in it out - with "
                + "Children too on, the label stops counting too and every tap reaches the box.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Neither is the same as disabled: with Disabled on, the label still takes "
                + "the tap and does nothing with it, and nothing in the layout answers.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
