import StateUI

/// A value that changes TRAVELS - under the default law, a spring or a long
/// eased one - or, under `.none`, arrives at once.
struct MotionSample: SampleContent, ExampleContent {
    static let id = "motion"
    static let title = "Motion"
    static let summary = "Assign the state and the control travels there - at a length, on a spring, or not at all."

    var examples: [Example] {
        [Example(self), Example(ChangeAwaited())]
    }

    // listing: MotionSample
    static let laws = ["Eased 200ms", "Spring", "Long and slow", "None"]

    static func law(_ index: Int) -> Motion {
        switch index {
        case 1: .spring(response: .milliseconds(320))
        case 2: .eased(.milliseconds(900), curve: .sineInOut)
        case 3: .none
        default: .standard
        }
    }

    @State private var law = 2
    @State private var wide = false
    @State private var warm = false
    @State(motion: .spring(response: .milliseconds(320))) private var reach = 120.0

    var body: some View {
        // NOTHING HERE SAYS "ANIMATE". A value that changes is a setpoint: the
        // tree says where the panel is going and the host carries it there.
        VStack {
            // The panels are described from `wide`, `warm` and `law`, read
            // here, so a press builds this closure once and the host walks
            // the rest.
            DebugInfoLabel()

            Text("A change that travels")
                .fontSize(11)
                .tracking(1)
                .textColor(Palette.subtle)

            panel(travels: true)

            Text("The same, told to stay still")
                .fontSize(11)
                .tracking(1)
                .textColor(Palette.subtle)

            panel(travels: false)

            Text("The same, holding only its size still")
                .fontSize(11)
                .tracking(1)
                .textColor(Palette.subtle)

            sized()

            HStack {
                Button("Size").onClicked { wide.toggle() }
                Button("Color").onClicked { warm.toggle() }
                Button(Self.laws[law]).onClicked { law = (law + 1) % Self.laws.count }
            }
            .spacing(8)

            Text("A move's own law, then the value's")
                .fontSize(11)
                .tracking(1)
                .textColor(Palette.subtle)

            Rectangle()
                .fill(Palette.brand)
                .width($reach)
                .height(24)
                .cornerRadius(6)
                .horizontalAlignment(.start)

            HStack {
                // The law given here is this move's alone...
                Button("Slow move").onClicked {
                    $reach.journey.move(to: 300, .eased(.milliseconds(2000), curve: .sineInOut))
                }
                // ...and a plain write travels on the value's own spring.
                Button("Back").onClicked { reach = 120 }
            }
            .spacing(8)
        }
        .spacing(10)
    }

    /// One panel, either traveling at the chosen law or arriving at once.
    private func panel(travels: Bool) -> some View {
        // `.motion` is per view: the chosen law, or `.none` to arrive at once.
        Rectangle()
            .fill(warm ? Palette.accent : Palette.brand)
            .width(wide ? 300 : 120)
            .height(wide ? 110 : 56)
            .cornerRadius(wide ? 28 : 8)
            .horizontalAlignment(.start)
            .motion(travels ? Self.law(law) : .none)
    }

    /// The same panel with a RULE: everything travels except its size, which
    /// `.size` takes to be its width and its height - its corners are its
    /// shape, and travel with the rest.
    private func sized() -> some View {
        Rectangle()
            .fill(warm ? Palette.accent : Palette.brand)
            .width(wide ? 300 : 120)
            .height(wide ? 110 : 56)
            .cornerRadius(wide ? 28 : 8)
            .horizontalAlignment(.start)
            .motion(Self.law(law))
            .motion(.none, .size)
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("Press Size or Color. The first panel travels, the second "
                + "arrives immediately, and the third holds only its size still.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Change the law to compare eased, spring, slow and immediate "
                + "motion. StateUI sends destinations; the host supplies the frames.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Press Slow move, then Back: the move takes two seconds, and Back "
                + "springs, because a law given to a move is that move's alone.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}

/// A change of the presentation awaited: what its writes started under one view, and how that ended.
struct ChangeAwaited: ExampleContent {
    // listing: ChangeAwaited
    @State private var shown = true
    @State private var said = "-"

    // THE VIEW A CHANGE WATCHES: everything its writes move in here.
    @Aim(VStack.self) private var panel

    var body: some View {
        VStack {
            VStack {
                Text("Saved to the drafts")
                    .fontSize(15)

                Text("A moment ago")
                    .fontSize(12)
                    .textColor(Palette.subtle)
                    // A LINE OF ITS OWN PACE, inside the panel: the change
                    // waits for it as it does for the panel.
                    .opacity(shown ? 1 : 0)
                    .motion(.eased(.milliseconds(1400)))
            }
            .spacing(4)
            .padding(16)
            .background(Palette.selected)
            .opacity(shown ? 1 : 0.15)
            .motion(.eased(.milliseconds(700)))
            .aim(panel)

            // THE WRITES RUN AT ONCE; what is awaited is what they started.
            // Pressed again before the fade has ended, the first change ends
            // interrupted - the second press's movement is the second's.
            // Each press is a run of its own, so both are heard.
            Button(shown ? "Hide" : "Show").onClicked(policy: .runConcurrently) {
                let change = try panel.presentationChange { shown.toggle() }
                said = "under way"
                switch try await change.settled() {
                case .settled: said = "settled"
                case .interrupted: said = "interrupted"
                case .notPresented: said = "not presented"
                }
            }
            .accessibilityIdentifier("change.toggle")

            Text("the change · \(said)")
                .accessibilityIdentifier("change.said")
                .fontSize(13)
                .horizontalTextAlignment(.center)
        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? {
        Text("Press Hide: the line reads `under way` until the slower of the two fades has ended, then "
            + "`settled`. Press again before that: the first change says `interrupted`, and the second "
            + "goes on to `settled`.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
