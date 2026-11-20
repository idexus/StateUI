import StateUI

/// A state given to the hand: a panel dragged between three places, and sent there by a button on the same value.
struct HandMovesStateSample: SampleContent, ExampleContent {
    // listing: HandMovesStateSample
    /// WHERE THE PANEL STANDS OR IS GOING: the buttons write it and the hand moves it - one value, traveling under
    /// the motion said here.
    @State(motion: .spring()) private var offset = 0.0
    // listing: end

    static let id = "handMovesState"
    static let title = "A state under the hand"
    static let summary = "An interaction gives a state to the hand: it moves the value itself, with no handler."

    // The panel is dragged, so the example is not put in a scroller: the page's would claim the drag first - see
    // SampleContent.scrolls.
    static let scrolls = false

    // listing: HandMovesStateSample
    var body: some View {
        VStack {
            // The hand builds no view: the label says so.
            DebugInfoLabel()

            // The track the panel moves along, the panel at its start.
            ZStack {
                Rectangle()
                    .fill(Palette.accent)
                    .cornerRadius(12)
                    .width(100)
                    .height(80)
                    .horizontalAlignment(.start)
                    // WHAT SHOWS THE STATE: the panel stands where the value is.
                    .translationX($offset)
                    // WHAT GIVES IT TO THE HAND: dragged, the value follows the hand a point a point, less and
                    // less past an end; let go, it is thrown on to the place nearest where the throw would end.
                    .interaction(
                        .value($offset, axis: \.self, input: .translation(.horizontal))
                            .range(0...240)
                            .snaps([120])
                            .release(.projected(.spring())))
                    .accessibilityIdentifier("panel")
            }
            .width(340)
            .height(80)
            .horizontalAlignment(.center)

            HStack {
                // THE PROGRAM WRITES THE SAME VALUE: caught on its way, the panel goes on from under the hand.
                Button("Start").onClicked { offset = 0 }

                Button("Middle").onClicked { offset = 120 }

                Button("End").onClicked { offset = 240 }
            }
            .spacing(8)
            .horizontalAlignment(.center)
        }
        .spacing(16)
    }
    // listing: end

    var notes: (any View)? {
        Text("Drag the panel: it rests at the start, the middle or the end, and a quick drag throws it on. The "
            + "buttons send it by writing the same state - catch it on its way. `.interaction(.value($offset, "
            + "axis: \\.self, input: .translation(.horizontal)).range(0...240).snaps([120]))` gives the state to "
            + "the hand; no handler runs and no view is built.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
