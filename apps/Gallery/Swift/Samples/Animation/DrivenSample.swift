import StateUI

/// A value both sides hold, moved by the host and read by arithmetic that
/// describes nothing.
struct DrivenSample: SampleContent {
    /// Where the marker sits - the value the HOST carries.
    @State(describing: .none) private var offset = AnimatedValue(0.0)

    /// What the reading says, which an engine works out from the marker.
    @State(describing: .none) private var reading = "0%"

    /// The rail's colour, which the HOST carries with no engine at all.
    @State(describing: .none) private var tint = AnimatedValue(Palette.outline)

    /// Which law the buttons send the marker under - ORDINARY state, read
    /// below so the caption can name it, which is what puts this page's build
    /// count next to a value that moves for nothing.
    @State private var slowly = false

    static let id = "number"
    static let title = "A value on a number"
    static let summary = "A value the host moves, and arithmetic that follows it every frame."

    /// How far the marker may travel - the rail's width less its own.
    private static let run = 240.0

    static let code = """
        @State(describing: .none) private var offset = AnimatedValue(0.0)
        @State(describing: .none) private var reading = "0%"
        @State(describing: .none) private var tint = AnimatedValue(Palette.outline)

        @State private var slowly = false

        // How often this view has been described, and the ONE value it is
        // described from.
        let info = debugInfo()
        let law = slowly ? "1600 ms, cubicInOut" : "350 ms, cubicOut"

        VStack {
            Label(info).textColor(Palette.accent)

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

            // Off a number: written sixty times a second, never described.
            Label().text($reading)

            // Off state: written twice a page, and described both times.
            Label(law)

            HStack {
                Button("Empty").onClicked { go(to: 0) }
                Button("Half").onClicked { go(to: 0.5) }
                Button("Full").onClicked { go(to: 1) }
            }

            SwitchRow("Take the long way", $slowly)
        }
        .following($offset) { _ in
            reading = "\\(Int((offset.value / 240 * 100).rounded()))%"
        }

        /// One place to be sent to, under whichever law the switch asks for.
        private func go(to place: Double) {
            let law: Motion = slowly ? .eased(1600, .cubicInOut) : .eased(350, .cubicOut)

            offset.motion = law
            offset.setPoint = 240 * place

            tint.motion = law
            tint.setPoint = place > 0 ? Palette.accent : Palette.outline
        }
        """

    var content: Element {
        // How often this view has been described, read where a reading goes.
        // It is the whole point of the page, and it takes BOTH lines to make
        // it: the caption below is described from `slowly`, so the count moves
        // when the switch is thrown and names the state it moved for - which
        // is what says the instrument is alive while the marker crosses under
        // it for nothing at all.
        let info = debugInfo()
        let law = slowly ? "1600 ms, cubicInOut" : "350 ms, cubicOut"

        return VStack {
            Label(info)
                .fontSize(12)
                .textColor(Palette.accent)
                .horizontalOptions(.start)

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
                .text($reading)
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
        .following($offset) { _ in
            reading = "\(Int((offset.value / Self.run * 100).rounded()))%"
        }
    }

    var notes: Element? {
        VStack {
            Label("A `@State(describing: .none)` is a value both sides hold, and a property wears one the "
                + "way it wears a value: `.translationX($offset)`, `.color($tint)`. "
                + "Give the number a setpoint from a handler - `offset.setPoint = 240` "
                + "under `offset.motion` - and the HOST carries the property there on "
                + "the display's own frames. Nothing is described on the way.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("`.following($offset)` runs on that same frame whenever a "
                + "number it follows has moved, and writes states of its own - so the "
                + "percentage follows the marker the whole way across.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("THE TWO READINGS ARE THE POINT. The percentage is written off a "
                + "number, sixty times a second; the line under it is written from "
                + "`slowly`, which is ordinary `@State`. The top line is "
                + "`debugInfo()`, naming how many times this view has been described "
                + "and WHICH value for. Press the buttons and watch the marker cross, "
                + "the colour change and the percentage count up: the number does not "
                + "move. Throw the switch, which changes one caption, and it goes up "
                + "by one and says `for slowly`.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("An `AnimatedValue` holds three things: `value` is where it IS, "
                + "`setPoint` where it is GOING, and `velocity` how fast. Writing the "
                + "setpoint asks the host for a journey; writing `value` puts it there "
                + "at once, which is what arithmetic worked out per frame does. A "
                + "`Label().text($reading)` is written only when the letters actually "
                + "change, so a reading that rounds to the same number costs nothing.")
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

        offset.motion = law
        offset.setPoint = Self.run * place

        tint.motion = law
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
