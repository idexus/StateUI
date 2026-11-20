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

    /// What the box does as it is let go: stays, springs home, or glides on
    /// from the hand's speed.
    @State private var letting = "Stays"
    static let lettings = ["Stays", "Springs home", "Glides on"]

    /// Where the box IS, driven - the host reads the translation off these on
    /// its own frames, so a drag costs the arithmetic and no renders at all.
    @State private var liveX = 0.0
    @State private var liveY = 0.0

    /// Where the hand holds the box, in the box's own points - driven words, so
    /// a report writes them without a render.
    @State private var held = "Hold the box"

    /// How far the box has got, in words an engine following both journeys
    /// writes on the host's frames.
    @State private var moved = "Moved 0, 0"
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
            // reading below is written by an engine following the same two,
            // and the switch is handed its state - this stands at one build.
            DebugInfoLabel()

            // A fixed box for it to move inside, so the layout does not follow
            // the view about.
            ZStack {
                Rectangle()
                    .fill(Palette.accent)
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
                        // `at` is in the box's own points: the same where
                        // the box is held, wherever it has been moved.
                        held = "Held at \(Int(update.at.x)), \(Int(update.at.y)) of the box"
                        switch update.phase {
                        case .changed:
                            follow(panX + update.total.x, panY + update.total.y)
                        case .ended where letting == "Springs home":
                            // Let go, a spring brings it home from where the
                            // hand left it.
                            (panX, panY) = (0, 0)
                            $liveX.journey.move(to: 0, .spring(response: .milliseconds(600), damping: 0.5))
                            $liveY.journey.move(to: 0, .spring(response: .milliseconds(600), damping: 0.5))
                        case .ended where letting == "Glides on":
                            // It goes on from the hand's speed. A cubic-out
                            // journey sets out three times as fast as it
                            // averages, so one a third of the speed's way long
                            // leaves at the hand's speed and slows to rest -
                            // kept inside the box.
                            let seconds = 0.9
                            panX = min(max(panX + update.total.x + update.velocity.x * seconds / 3, -140), 140)
                            panY = min(max(panY + update.total.y + update.velocity.y * seconds / 3, -60), 60)
                            $liveX.journey.move(to: panX, .eased(.seconds(seconds), curve: .cubicOut))
                            $liveY.journey.move(to: panY, .eased(.seconds(seconds), curve: .cubicOut))
                        case .ended:
                            panX += update.total.x
                            panY += update.total.y
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

            // Two journeys followed by one engine: on the host's frames it
            // reads where the box HAS GOT TO - both samples of one frame - and
            // writes the words.
            Text($moved)
                .fontSize(15)
                .horizontalTextAlignment(.center)
                .engine(following: $liveX.journey, $liveY.journey) { _ in
                    guard let x = $liveX.journey.sample, let y = $liveY.journey.sample else { return }
                    moved = "Moved \(Int(x.value)), \(Int(y.value))"
                }

            Text($held)
                .fontSize(13)
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)
                .accessibilityIdentifier("pan.held")

            SwitchRow("The drag snaps", $snaps)
            // What the box does as the hand lets it go.
            Picker(Self.lettings, selection: $letting) { $0 }
                .accessibilityLabel("Let go")
                .presentation(.segmented)

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
    /// `$liveX.journey.snap(to:)` - here, going nowhere, standing still. The
    /// state itself is where it is GOING, so writing THAT on every report
    /// starts a fresh little journey the next report interrupts, which is the
    /// lag the switch is here to show.
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

            Text("Each report says how fast the hand goes, `velocity`, "
                + "a second - at the end, as fast as it lifted. `Springs home` sends the "
                + "box back on a spring. `Glides on` sends it a third of that speed's way "
                + "on, on a cubic-out journey, which sets out at the hand's speed and "
                + "slows to rest.")
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
