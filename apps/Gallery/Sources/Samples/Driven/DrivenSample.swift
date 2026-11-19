import StateUI

/// A value both sides hold, moved by the host and read by arithmetic that
/// describes nothing.
struct DrivenSample: SampleContent, ExampleContent {
    // listing: DrivenSample
    /// Which law the buttons send the marker under - ORDINARY state, read
    /// below so the caption can name it, which is what puts this page's build
    /// count next to a value that moves for nothing.
    @State private var slowly = false

    /// Where the marker sits - the value the HOST carries.
    @State private var offset = 0.0

    /// The rail's color, which the HOST carries with no engine at all.
    @State private var tint = Palette.outline

    /// How far the marker has got, in words the engine below writes and the
    /// host shows: no body reads them.
    @State private var percent = "0%"
    // listing: end

    static let id = "driven"
    static let title = "A value the host moves"
    static let summary = "A value the host moves, and arithmetic that follows it every frame."

    // listing: DrivenSample
    /// How far the marker may travel - the rail's width less its own.
    private static let run = 240.0

    var body: some View {
        VStack {
            // WHAT THIS PAGE IS ABOUT, and it takes both halves to say it: the
            // marker crosses and the percentage counts up for no build at all,
            // while the caption below is described from `slowly` - so the only
            // thing that moves this reading is the switch, which it names.
            DebugInfoLabel()

            let law = slowly ? "1600 ms, cubicInOut" : "350 ms, cubicOut"

            ZStack {
                Grid {
                    Rectangle()
                        .fill($tint)
                        .height(6)
                        .cornerRadius(3)
                        .verticalAlignment(.center)

                    Rectangle()
                        .fill(Palette.brand)
                        .width(20)
                        .height(20)
                        .cornerRadius(10)
                        .horizontalAlignment(.start)
                        .verticalAlignment(.center)
                        .translationX($offset)
                }
                .width(260)
                .height(28)
            }
            .style(.card)
            .padding(16)
            .background(Palette.well)
            .stroke(.transparent)
            .shape(.roundedRectangle(12))
            .horizontalAlignment(.center)

            // WORDS AN ENGINE WRITES, following the same value's journey: on the
            // host's frames it reads where the marker HAS GOT TO and writes
            // the percentage, and nothing here reads anything.
            Text($percent)
                .fontSize(28)
                .fontWeight(.bold)
                .horizontalAlignment(.center)
                .engine(following: $offset.journey) { _ in
                    guard let sample = $offset.journey.sample else { return }
                    percent = "\(Int((sample.value / Self.run * 100).rounded()))%"
                }

            // Off ordinary state: described again each time the switch is
            // thrown.
            Text("Sent under \(law)")
                .fontSize(12)
                .textColor(Palette.subtle)
                .horizontalAlignment(.center)

            HStack {
                button("Empty") { try go(to: 0) }
                button("Half") { try go(to: 0.5) }
                button("Full") { try go(to: 1) }
            }
            .spacing(8)
            .horizontalAlignment(.center)

            SwitchRow("Take the long way", $slowly)
        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("The reading at the top says how many times this closure has been "
                + "described and which value for. Press the buttons and watch the marker "
                + "cross, the color change and the percentage count up: the count does "
                + "not move. Throw the switch, which changes one caption, and it goes up "
                + "by one and says `for slowly`. The percentage is written by an engine "
                + "following a driven value's journey; the caption under it is described "
                + "from `slowly`, which is ordinary `@State`.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("A value the host holds is worn by a property the way a plain value is: "
                + "`.translationX($offset)`, `.fill($tint)`. Send it somewhere from a "
                + "handler - `offset = 240`, under the motion `$offset.journey.setMotion(_:)` "
                + "gave it - and the host "
                + "walks the property there on the display's own frames, which the tree "
                + "does not have. A journey is part of every `@State` the host can walk, "
                + "so both values here are ordinary `@State`; nothing reads either in a "
                + "body, and the run costs no render at all.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("`offset` itself is where the value is going. Where the host shows it is "
                + "`$offset.journey.sample`: where it stands on this frame, where the host "
                + "is taking it and how fast - or nothing, while no view shows the state. "
                + "Writing the state asks the host for a journey; `$offset.journey.snap(to:)` "
                + "puts the value there at once. `.engine(following: $offset.journey)` runs "
                + "on every frame the marker moves and writes the percentage from the "
                + "sample; words that come out the same are no write, so a reading that "
                + "rounds to the same number costs nothing.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("A conversion rewrites where one value is going as another; an engine "
                + "following a journey reads where it has got to, and one may keep state "
                + "of its own between frames, which Engine shows. The "
                + "marker moves rather than resizing: a translation is a drawing field and "
                + "costs no layout, while a width written per frame measures the layout again "
                + "every time. Wherever a value moves quickly, reach for the transform.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }

    // listing: DrivenSample
    /// One place to be sent to, under whichever law the switch asks for.
    private func go(to place: Double) throws {
        let law: Motion = slowly ? .eased(.milliseconds(1600), curve: .cubicInOut) : .eased(.milliseconds(350), curve: .cubicOut)

        // The motion is the value's own: the next destination travels under it.
        try $offset.journey.setMotion(law)
        offset = Self.run * place

        try $tint.journey.setMotion(law)
        tint = place > 0 ? Palette.accent : Palette.outline
    }

    /// One of the buttons, all of which look the same.
    private func button(_ caption: String, _ act: @escaping @MainActor () throws -> Void) -> Button {
        Button(caption)
            .onClicked(act)
    }
    // listing: end
}
