import StateUI

/// A value both sides hold, moved by the host and read by arithmetic that
/// describes nothing.
struct DrivenSample: SampleContent {
    /// Which law the buttons send the marker under - ORDINARY state, read
    /// below so the caption can name it, which is what puts this page's build
    /// count next to a value that moves for nothing.
    @State private var slowly = false

    /// Where the marker sits - the value the HOST carries.
    @State private var offset = AnimatedValue(0.0)

    /// The rail's colour, which the HOST carries with no engine at all.
    @State private var tint = AnimatedValue(Palette.outline)

    static let id = "driven"
    static let title = "A value the host moves"
    static let summary = "A value the host moves, and arithmetic that follows it every frame."

    /// How far the marker may travel - the rail's width less its own.
    private static let run = 240.0

    static let code = """
        @State private var offset = AnimatedValue(0.0)
        @State private var tint = AnimatedValue(Palette.outline)

        @State private var slowly = false

        VStack {
            // The marker and the percentage cost no build at all; the
            // caption below reads `slowly`, so the switch is the only thing
            // that moves this reading - and it names it.
            DebugInfoLabel()

            let law = slowly ? "1600 ms, cubicInOut" : "350 ms, cubicOut"

            Grid {
                BoxView()
                    .color($tint)
                    .heightRequest(6)
                    .verticalOptions(.center)

                BoxView()
                    .color(Palette.brand)
                    .widthRequest(20)
                    .heightRequest(20)
                    .horizontalOptions(.start)
                    .translationX($offset)
            }
            .widthRequest(260)
            .heightRequest(28)

            // A CONVERSION of the same driven value: the host works the words
            // out on its own frames, from where the marker HAS GOT TO, and
            // nothing here reads anything.
            Label().text($offset.convert { "\\(Int(($0.value / 240 * 100).rounded()))%" })

            // Off state: written twice a page, and described both times.
            Label(law)

            HStack {
                Button("Empty").onClicked { go(to: 0) }
                Button("Half").onClicked { go(to: 0.5) }
                Button("Full").onClicked { go(to: 1) }
            }

            SwitchRow("Take the long way", $slowly)
        }
        /// One place to be sent to, under whichever law the switch asks for.
        private func go(to place: Double) {
            let law: Motion = slowly ? .eased(1600, .cubicInOut) : .eased(350, .cubicOut)

            $offset.motion = law
            offset.setPoint = 240 * place

            $tint.motion = law
            tint.setPoint = place > 0 ? Palette.accent : Palette.outline
        }
        """

    var content: Element {
        VStack {
            // WHAT THIS PAGE IS ABOUT, and it takes both halves to say it: the
            // marker crosses and the percentage counts up for no build at all,
            // while the caption below is described from `slowly` - so the only
            // thing that moves this reading is the switch, which it names.
            DebugInfoLabel()

            let law = slowly ? "1600 ms, cubicInOut" : "350 ms, cubicOut"

            Border {
                Grid {
                    BoxView()
                        .color($tint)
                        .heightRequest(6)
                        .cornerRadius(3)
                        .verticalOptions(.center)

                    BoxView()
                        .color(Palette.brand)
                        .widthRequest(20)
                        .heightRequest(20)
                        .cornerRadius(10)
                        .horizontalOptions(.start)
                        .verticalOptions(.center)
                        .translationX($offset)
                }
                .widthRequest(260)
                .heightRequest(28)
            }
            .padding(16)
            .backgroundColor(Palette.surface)
            .stroke(.transparent)
            .strokeShape(.roundRectangle(12))
            .horizontalOptions(.center)

            Label()
                .text($offset.convert { "\(Int(($0.value / Self.run * 100).rounded()))%" })
                .fontSize(28)
                .fontAttributes(.bold)
                .horizontalOptions(.center)

            Label("Sent under \(law)")
                .fontSize(12)
                .textColor(Palette.subtle)
                .horizontalOptions(.center)

            HStack {
                button("Empty") { go(to: 0) }
                button("Half") { go(to: 0.5) }
                button("Full") { go(to: 1) }
            }
            .spacing(8)
            .horizontalOptions(.center)

            SwitchRow("Take the long way", $slowly)
        }
        .spacing(12)
    }

    var notes: Element? {
        VStack {
            Label("A value the HOST holds is worn by a property the way a plain "
                + "value is: `.translationX($offset)`, `.color($tint)`. Send it "
                + "somewhere from a handler - `offset.setPoint = 240`, under "
                + "`$offset.motion` - and the HOST carries the property there on "
                + "the display's own frames. Nothing is described on the way.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("A JOURNEY IS A `@State`'s. What closes the gap between where a "
                + "value is and where it is going is the HOST walking it, on its own "
                + "frames - the tree has none to walk one on. So the two values here "
                + "are ordinary `@State`s holding an `AnimatedValue`, and what makes "
                + "that affordable is that nothing reads either of them in a body: "
                + "they are handed on with `$`, and the run costs no render at all.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("`$offset.convert { … }` is what writes the percentage: a second "
                + "state the host works out from the first, on the same frames the "
                + "marker moves on, so the words follow it the whole way across for no "
                + "render at all. A rewriting of one value into another is what a "
                + "conversion is for; an engine is for arithmetic that keeps state of "
                + "its own in `@Memory`, which Engine shows.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("THE TWO READINGS ARE THE POINT. The percentage is written off a "
                + "driven value by a conversion; the line under it is described from "
                + "`slowly`, which is ordinary `@State`. The reading at the top says "
                + "how many times this closure has been described and WHICH value for. "
                + "Press the buttons and watch the marker cross, the colour change and "
                + "the percentage count up: the count does not move. Throw the switch, "
                + "which changes one caption, and it goes up by one and says "
                + "`for slowly`.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("An `AnimatedValue` holds three things at once: `setPoint` is "
                + "where the value is GOING, `$offset.value` is where it IS, and "
                + "`$offset.velocity` how fast. Writing `setPoint` asks the host for a "
                + "journey; writing `$offset.value` puts it there at once, which is "
                + "what arithmetic worked out per frame does. A "
                + "converted text is written only when the letters actually change, so "
                + "a reading that rounds to the same number costs nothing.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The marker MOVES rather than resizing: a translation is a drawing "
                + "field and costs nothing, while a width written per frame measures "
                + "the layout again every time. It is the same rule wherever a value "
                + "moves quickly - reach for the transform.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }

    /// One place to be sent to, under whichever law the switch asks for.
    private func go(to place: Double) {
        let law: Motion = slowly ? .eased(1600, .cubicInOut) : .eased(350, .cubicOut)

        $offset.motion = law
        offset.setPoint = Self.run * place

        $tint.motion = law
        tint.setPoint = place > 0 ? Palette.accent : Palette.outline
    }

    /// One of the buttons, all of which look the same.
    private func button(_ caption: String, _ act: @escaping EventHandler) -> Button {
        Button(caption)
            .fontSize(13)
            .padding(14, 6)
            .onClicked(act)
    }
}
