import StateUI

/// A link to the bus: the parent lays the bus with `@Bus`, two children each
/// have a link to it with `@Link`, and every spelling is the same at every depth.
struct BusSample: SampleContent {
    /// Where the level is going and where it has got to - the one value this
    /// page is about, owned here and shared with both children below.
    @Bus private var level = AnimatedValue(0.2)

    /// The reading, written by the knob's engine and shown by the meter: a
    /// second bus, so the two children talk to each other through the host and
    /// never through a render.
    @Bus private var reading = "20%"

    static let id = "bus"
    static let title = "A link to the bus"
    static let summary = "Two child views, a link each to one bus: @Link, the same spelling at every depth."

    static let code = """
        @Bus private var level = AnimatedValue(0.2)
        @Bus private var reading = "20%"

        VStack {
            // The knob has a link to the bus: it drags the level, sends it on a
            // journey and writes the reading - without owning any of it.
            Knob(level: $level, reading: $reading)

            // The meter has a link to the same two buses, and shows both.
            Meter(level: $level, reading: $reading)
        }

        private struct Knob: ContentView {
            @Link var level: AnimatedValue<Double>
            @Link var reading: String

            var content: Element {
                VStack {
                    // The same spelling as on the owner: $level is the link.
                    Slider($level)

                    HStack {
                        Button("Full").onClicked {
                            try await $level.animateTo(1, .eased(600, .cubicOut))
                        }

                        Button("Empty").onClicked {
                            try await $level.animateTo(0, .eased(600, .cubicOut))
                        }
                    }
                }
                // Following a bus from a child: named, so every frame of a
                // journey wakes it - and what it writes is the other bus.
                .engine(following: $level) { _ in
                    reading = "\\(Int(($level.value * 100).rounded()))%"
                }
            }
        }

        private struct Meter: ContentView {
            @Link var level: AnimatedValue<Double>
            @Link var reading: String

            var content: Element {
                VStack {
                    // Driven from a bus this view does not own.
                    BoxView(.cornflowerBlue)
                        .heightRequest(10)
                        .anchorX(0)
                        .scaleX($level)

                    // The host's text, written by the knob's engine.
                    Label().text($reading)
                }
            }
        }
        """

    var example: Element {
        VStack {
            Knob(level: $level, reading: $reading)

            Meter(level: $level, reading: $reading)
        }
        .spacing(18)
    }

    var notes: Element? {
        VStack {
            Label("`$level` on a `@Bus` is a `Link` - a two-way connection to the bus - "
                + "and a child declares its own link with `@Link`. The parent hands the "
                + "link over in the child's initializer, `Knob(level: $level)`, exactly as "
                + "a binding is handed over. In the child, `level` is the value and `$level` "
                + "is the link again, so `Slider($level)`, `.scaleX($level)`, "
                + "`following: $level` and `$level.animateTo(…)` are written the same way at "
                + "every depth.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Nothing on this page renders while it moves: the knob's drag lands in "
                + "the image, the journey is walked by the host, the meter's bar is driven "
                + "from the bus and the reading is a text the host carries. The knob's "
                + "engine follows the level and writes the reading onto the second bus, so "
                + "the two children talk through the host and the count in the corner "
                + "stays at one.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("`@Binding` is the tree's and `@Link` is the host's, and they share no "
                + "type: a `@State` handed where a link is wanted does not compile, and "
                + "neither does `.scaleX($counter)` over one. The pair is the same one "
                + "twice: the owner names the thing - a state, a bus - and the borrower "
                + "names the connection to it - a binding, a link.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}

/// The input, on the parent's two buses: drags the level, sends it on a
/// journey, and writes the reading the meter shows.
private struct Knob: ContentView {
    @Link var level: AnimatedValue<Double>

    @Link var reading: String

    var content: Element {
        VStack {
            Slider($level)

            HStack {
                Button("Full")
                    .backgroundColor(Palette.accent)
                    .cornerRadius(8)
                    .padding(16, 8)
                    .onClicked {
                        try await $level.animateTo(1, .eased(600, .cubicOut))
                    }

                Button("Empty")
                    .borderColor(Palette.outline)
                    .borderWidth(1)
                    .backgroundColor(.transparent)
                    .textColor(Palette.subtle)
                    .cornerRadius(8)
                    .padding(16, 8)
                    .onClicked {
                        try await $level.animateTo(0, .eased(600, .cubicOut))
                    }
            }
            .spacing(10)
        }
        .spacing(12)
        .engine(following: $level) { _ in
            reading = "\(Int(($level.value * 100).rounded()))%"
        }
    }
}

/// The output, on the same two buses: a bar driven from the level, and the
/// reading as the host carries it.
private struct Meter: ContentView {
    @Link var level: AnimatedValue<Double>

    @Link var reading: String

    var content: Element {
        VStack {
            BoxView(Palette.accent)
                .heightRequest(10)
                .cornerRadius(5)
                .anchorX(0)
                .scaleX($level)

            Label()
                .text($reading)
                .fontSize(17)

            Label("a bar driven from the bus, and a text the host carries")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
