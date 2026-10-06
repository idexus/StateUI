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

    /// The rail's colour, which the HOST carries with no engine at all.
    @State private var tint = Palette.outline
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
                    ColorBox()
                        .color($tint)
                        .height(6)
                        .cornerRadius(3)
                        .verticalAlignment(.center)

                    ColorBox()
                        .color(Palette.brand)
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
            .style("Card")
            .padding(16)
            .background(Palette.surface)
            .stroke(.transparent)
            .shape(.roundedRectangle(12))
            .horizontalAlignment(.center)

            // A CONVERSION of the same driven value: the host works the words
            // out on its own frames, from where the marker HAS GOT TO, and
            // nothing here reads anything.
            Text()
                .text($offset.journey.convert { "\(Int(($0.value / Self.run * 100).rounded()))%" })
                .fontSize(28)
                .fontAttributes(.bold)
                .horizontalAlignment(.center)

            // Off ordinary state: described again each time the switch is
            // thrown.
            Text("Sent under \(law)")
                .fontSize(12)
                .textColor(Palette.subtle)
                .horizontalAlignment(.center)

            HStack {
                button("Empty") { go(to: 0) }
                button("Half") { go(to: 0.5) }
                button("Full") { go(to: 1) }
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
                + "cross, the colour change and the percentage count up: the count does "
                + "not move. Throw the switch, which changes one caption, and it goes up "
                + "by one and says `for slowly`. The percentage is written off a driven "
                + "value by a conversion; the caption under it is described from "
                + "`slowly`, which is ordinary `@State`.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("A value the host holds is worn by a property the way a plain value is: "
                + "`.translationX($offset)`, `.color($tint)`. Send it somewhere from a "
                + "handler - `offset = 240`, under `$offset.journey.motion` - and the host "
                + "walks the property there on the display's own frames, which the tree "
                + "does not have. A journey is part of every `@State` the host can walk, "
                + "so both values here are ordinary `@State`; nothing reads either in a "
                + "body, and the run costs no render at all.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("`$offset.journey` holds where the value is going, where it is and how "
                + "fast: `offset` itself is the destination, `$offset.journey.value` where "
                + "it is, and `$offset.journey.velocity` how fast. Writing the state asks the "
                + "host for a journey; `$offset.journey.snap(to:)` puts the value there at "
                + "once, while a write to `$offset.journey.value` moves only what is shown "
                + "and the host goes straight back to the destination. `$offset.journey.convert "
                + "{ … }` writes the percentage from where the marker has got to, and a "
                + "converted text is written only when its letters change, so a reading "
                + "that rounds to the same number costs nothing.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("A conversion rewrites one value as another; an engine is for arithmetic "
                + "that keeps state of its own between frames, which Engine shows. The "
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
    private func go(to place: Double) {
        let law: Motion = slowly ? .eased(1600, .cubicInOut) : .eased(350, .cubicOut)

        $offset.journey.motion = law
        offset = Self.run * place

        $tint.journey.motion = law
        tint = place > 0 ? Palette.accent : Palette.outline
    }

    /// One of the buttons, all of which look the same.
    private func button(_ caption: String, _ act: @escaping EventHandler) -> Button {
        Button(caption)
            .fontSize(13)
            .padding(horizontal: 14, vertical: 6)
            .onClicked(act)
    }
    // listing: end
}
