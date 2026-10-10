import StateUI

/// A view dragged about under a finger, and the one write that must not travel.
struct PanSample: SampleContent, ExampleContent {
    // listing: PanSample
    /// Where the box was left. Ordinary state, read by the handlers alone: it
    /// changes once per gesture, and no view is built for it.
    @State private var panX = 0.0
    @State private var panY = 0.0

    /// Whether the reading written on every report is a SNAP.
    @State private var snaps = true

    /// Where the box IS, driven - the host reads the translation off these on
    /// its own frames, so a drag costs the arithmetic and no renders at all.
    @State private var liveX = 0.0
    @State private var liveY = 0.0
    // listing: end

    static let id = "pan"
    static let title = "Pan"
    static let summary = "Dragging a view from where it was to where it is let go."

    // A gesture sample is not put in a scroller: a scroller would claim the
    // drag before the example heard about it, so the page holds the example
    // still - see SampleContent.scrolls.
    static let scrolls = false

    // listing: PanSample
    var body: some View {
        VStack {
            // The box is moved by DRIVEN states, so a drag builds nothing: the
            // reading below is a CONVERSION of the same two, and the switch is
            // handed its state - this stands at one build.
            DebugInfoLabel()

            // A fixed box for it to move inside, so the layout does not follow
            // the view about.
            ZStack {
                ColorBox(Palette.accent)
                    .cornerRadius(10)
                    .width(64)
                    .height(64)
                    .horizontalAlignment(.center)
                    .verticalAlignment(.center)
                    // DRIVEN, both of them: the host reads the translation off
                    // the state every frame, and no report renders anything.
                    .translationX($liveX)
                    .translationY($liveY)
                    .onPanUpdated { update in
                        switch update.phase {
                        case .changed:
                            follow(panX + update.totalX, panY + update.totalY)
                        case .ended:
                            panX = $liveX.journey.value
                            panY = $liveY.journey.value
                        case .cancelled:
                            follow(panX, panY)
                        case .began:
                            break
                        }
                    }
            }
            .style(.card)
            .stroke(Palette.outline)
            .lineWidth(1)
            .shape(.roundedRectangle(10))
            .height(200)

            // Two states into one conversion: the host works the words out
            // from where the box HAS GOT TO, on its own frames.
            Text()
                .text($liveX.journey.convert(with: $liveY.journey) { x, y in
                    "Moved \(Int(x.value)), \(Int(y.value))"
                })
                .fontSize(15)
                .horizontalTextAlignment(.center)

            SwitchRow("The drag snaps", $snaps)

            Button("Put it back")
                .horizontalAlignment(.center)
                // A SETPOINT, so the box TRAVELS home from wherever it was
                // left - the same two states, written the other way.
                .onClicked {
                    panX = 0
                    panY = 0
                    liveX = 0
                    liveY = 0
                }
        }
        .spacing(12)

    }

    /// The box under the finger.
    ///
    /// A READING WRITTEN ON EVERY REPORT IS A SNAP, and the snap is
    /// `$liveX.journey.snap(to:)` - here, going nowhere, standing still.
    /// Writing `$liveX.journey.value` alone would move the box and leave the
    /// destination where it was, so `Put it back` would have nothing to
    /// change. The state itself is where it is GOING, so writing THAT on every
    /// report starts a fresh little journey the next report interrupts, which
    /// is the lag the switch is here to show.
    private func follow(_ x: Double, _ y: Double) {
        if snaps {
            // HERE, GOING NOWHERE, STANDING STILL - all three, so that
            // `Put it back` has a destination to change.
            $liveX.journey.snap(to: x)
            $liveY.journey.snap(to: y)
        } else {
            liveX = x
            liveY = y
        }
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("The totals are measured from where the pan BEGAN, not from "
                + "the last report - which is why the changed case adds them to "
                + "where the view was, and the ended case is what commits "
                + "the move.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("`The drag snaps` is the whole lesson, and on a walked state it is "
                + "the choice of which part to write. `$liveX.journey.snap(to:)` puts "
                + "the box under the finger, going nowhere, standing still. The state "
                + "itself is where it is GOING, so writing that on every report starts "
                + "a journey the next report interrupts - turn the switch off and the "
                + "box trails the hand.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("`Put it back` writes the states instead, which is the same two "
                + "states written the other way: the box travels home rather than "
                + "jumping there.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Nothing on this page is described while the box moves. The "
                + "translation is read off the state by the host, and the caption is a "
                + "converted text over the same two states - so a drag of a hundred "
                + "reports costs "
                + "a hundred pieces of arithmetic and no renders.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
