import StateUI

/// MAUI: PanGestureRecognizer.
struct PanSample: SampleContent {
    /// Where the box was left. Ordinary state: it changes once per gesture, so
    /// describing it costs one render at the end of a drag.
    @State private var panX = 0.0
    @State private var panY = 0.0

    /// Whether the reading written on every report is a SNAP.
    @State private var snaps = true

    /// Where the box IS, driven - the host reads the translation off these on
    /// its own frames, so a drag costs the arithmetic and no renders at all.
    @State private var liveX = 0.0
    @State private var liveY = 0.0

    static let id = "pan"
    static let title = "Pan"
    static let summary = "Dragging a view about, from where it was to where it is let go - and the one write that must not travel."

    // A gesture sample is not put in a scroller: the scroller would claim the
    // drag before the example heard about it. The code below it scrolls
    // instead - see SampleContent.scrolls.
    static let scrolls = false

    static let code = """
        @State private var panX = 0.0
        @State private var panY = 0.0

        // Driven: the host reads the translation off these, so a drag renders
        // nothing at all.
        @State private var liveX = 0.0
        @State private var liveY = 0.0

        /// Whether the reading written on every report is a SNAP.
        @State private var snaps = true

        VStack {
            // The box is moved by DRIVEN states, so a drag builds nothing: the
            // reading below is a CONVERSION of the same two, and the switch is
            // handed its state - this stands at one build.
            DebugInfoLabel()

            // A fixed box for it to move inside, so the layout does not follow
            // the view about.
            Border {
                BoxView(Palette.accent)
                    .widthRequest(64)
                    .heightRequest(64)
                    // DRIVEN, both of them.
                    .translationX($liveX)
                    .translationY($liveY)
                    .onPanUpdated { update in
                        switch update.status {
                        case .running:
                            follow(panX + update.totalX, panY + update.totalY)
                        case .completed:
                            panX = $liveX.journey.value
                            panY = $liveY.journey.value
                        case .canceled:
                            follow(panX, panY)
                        case .started:
                            break
                        }
                    }
            }
            .heightRequest(200)

            // Two states into one conversion: the host works the words out
            // from where the box HAS GOT TO, on its own frames.
            Label($liveX.journey.convert(with: $liveY.journey) { x, y in
                "Moved \\(Int(x.value)), \\(Int(y.value))"
            })

            SwitchRow("The drag snaps", $snaps)

            // A SETPOINT, so the box travels home from wherever it was left.
            Button("Put it back").onClicked {
                panX = 0
                panY = 0
                liveX = 0
                liveY = 0
            }
        }


        /// The box under the finger.
        ///
        /// A READING WRITTEN ON EVERY REPORT IS A SNAP, and on a walked state
        /// the snap is `$liveX.journey.snap(to:)` - where the box IS. The
        /// state itself is where it is GOING, so writing that on every report
        /// starts a fresh little journey the next report interrupts, and the
        /// box trails the hand.
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
        """

    var content: any View {
        VStack {
            DebugInfoLabel()

            // A fixed box for it to move inside, so the layout does not follow
            // the view about.
            Border {
                BoxView(Palette.accent)
                    .cornerRadius(10)
                    .widthRequest(64)
                    .heightRequest(64)
                    .horizontalOptions(.center)
                    .verticalOptions(.center)
                    // DRIVEN, both of them: the host reads the translation off
                    // the state every frame, and no report renders anything.
                    .translationX($liveX)
                    .translationY($liveY)
                    .onPanUpdated { update in
                        switch update.status {
                        case .running:
                            follow(panX + update.totalX, panY + update.totalY)
                        case .completed:
                            panX = $liveX.journey.value
                            panY = $liveY.journey.value
                        case .canceled:
                            follow(panX, panY)
                        case .started:
                            break
                        }
                    }
            }
            .stroke(Palette.outline)
            .strokeThickness(1)
            .strokeShape(.roundRectangle(10))
            .heightRequest(200)

            Label()
                .text($liveX.journey.convert(with: $liveY.journey) { x, y in
                    "Moved \(Int(x.value)), \(Int(y.value))"
                })
                .fontSize(15)
                .horizontalTextAlignment(.center)

            SwitchRow("The drag snaps", $snaps)

            Button("Put it back")
                .fontSize(13)
                .padding(16, 6)
                .horizontalOptions(.center)
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
            $liveX.journey.snap(to: x)
            $liveY.journey.snap(to: y)
        } else {
            liveX = x
            liveY = y
        }
    }

    var notes: Element? {
        VStack {
            Label("The totals are measured from where the pan BEGAN, not from "
                + "the last report - which is why the running case adds them to "
                + "where the view was, and the completed case is what commits "
                + "the move.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("`The drag snaps` is the whole lesson, and on a walked state it is "
                + "the choice of which part to write. `$liveX.journey.snap(to:)` puts "
                + "the box under the finger, going nowhere, standing still. The state "
                + "itself is where it is GOING, so writing that on every report starts "
                + "a journey the next report interrupts - turn the switch off and the "
                + "box trails the hand.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("`Put it back` writes the states instead, which is the same two "
                + "states written the other way: the box travels home rather than "
                + "jumping there.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Nothing on this page is described while the box moves. The "
                + "translation is read off the state by the host, and the caption is a "
                + "converted text over the same two states - so a drag of a hundred "
                + "reports costs "
                + "a hundred pieces of arithmetic and no renders.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
