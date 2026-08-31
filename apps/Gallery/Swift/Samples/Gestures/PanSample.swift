import StateUI

/// MAUI: PanGestureRecognizer.
struct PanSample: SampleContent {
    /// Where the box was left, and where it is being dragged to.
    @State private var panX = 0.0
    @State private var panY = 0.0
    @State private var liveX = 0.0
    @State private var liveY = 0.0

    /// Whether the reading written on every report is SNAPPED.
    @State private var snaps = true

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
        @State private var liveX = 0.0
        @State private var liveY = 0.0

        VStack {
            // A fixed box for it to move inside, so the layout does not follow
            // the view about.
            Border {
                BoxView(Palette.accent)
                    .widthRequest(64)
                    .heightRequest(64)
                    .horizontalOptions(.center)
                    .verticalOptions(.center)
                    // ARMED: a modifier written from a binding is a binding the
                    // write can then say something about.
                    .translationX($liveX)
                    .translationY($liveY)
                    .onPanUpdated { update in
                        switch update.status {
                        case .running:
                            // A VALUE THAT FOLLOWS A FINGER DOES NOT TRAVEL. A
                            // change travels to its new setting by default,
                            // which is right for almost everything and exactly
                            // wrong here: a translation written on every report
                            // and filtered through a fifth of a second lags
                            // visibly behind the hand. `snap(to:)` is one write
                            // held still; the next one travels again.
                            $liveX.snap(to: panX + update.totalX)
                            $liveY.snap(to: panY + update.totalY)
                        case .completed:
                            panX = liveX
                            panY = liveY
                        case .canceled:
                            $liveX.snap(to: panX)
                            $liveY.snap(to: panY)
                        case .started:
                            break
                        }
                    }
            }
            .heightRequest(200)

            Label("Moved \\(Int(liveX)), \\(Int(liveY))")

            // AN ORDINARY WRITE, so the box FLIES home from wherever it was
            // left - the same two states, and nothing about them is special.
            Button("Put it back")
                .onClicked {
                    panX = 0
                    panY = 0
                    liveX = 0
                    liveY = 0
                }
        }
        """

    var content: Element {
        VStack {
            // A fixed box for it to move inside, so the layout does not follow
            // the view about.
            Border {
                BoxView(Palette.accent)
                    .cornerRadius(10)
                    .widthRequest(64)
                    .heightRequest(64)
                    .horizontalOptions(.center)
                    .verticalOptions(.center)
                    // ARMED, both of them: a modifier written from a binding is
                    // a binding the write can then say something about.
                    .translationX($liveX)
                    .translationY($liveY)
                    .onPanUpdated { update in
                        switch update.status {
                        case .running:
                            follow(panX + update.totalX, panY + update.totalY)
                        case .completed:
                            panX = liveX
                            panY = liveY
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

            Label("Moved \(Int(liveX)), \(Int(liveY))")
                .fontSize(15)
                .horizontalTextAlignment(.center)

            SwitchRow("The drag snaps", $snaps)

            Button("Put it back")
                .fontSize(13)
                .padding(16, 6)
                .horizontalOptions(.center)
                // AN ORDINARY WRITE, so the box FLIES home from wherever it was
                // left. One snap is one write; the next one travels again.
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
    /// A READING WRITTEN ON EVERY REPORT IS SNAPPED: `snap(to:)` writes the
    /// value with no motion, so the box is where the finger is rather than on
    /// its way there. Turned off, the same two numbers are assigned plainly and
    /// every report starts a fresh little journey the next one interrupts -
    /// which is the lag the switch is here to show.
    private func follow(_ x: Double, _ y: Double) {
        if snaps {
            $liveX.snap(to: x)
            $liveY.snap(to: y)
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

            Label("`The drag snaps` is the whole lesson. A value that changes "
                + "travels to its new setting, which is right for almost "
                + "everything and exactly wrong for a reading written on every "
                + "report: turn it off and the box trails the hand. "
                + "`$liveX.snap(to:)` writes one value with no motion.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("It is one WRITE and not a setting, which `Put it back` "
                + "shows: an ordinary assignment to the same two states, and "
                + "the box flies home.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
