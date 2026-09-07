import StateUI

/// A binding is no reader: one state, handed on as `$level` to a knob that
/// drags it and to two meters that show it - one by reading the value, one by
/// a text an engine writes - and each meter wears its own build count.
struct BindingReaderSample: SampleContent {
    /// The one value this page is about, owned here and handed on to every
    /// child as `$level`. This body never reads it.
    @State private var level = 0.2

    /// The reading, written by the knob's engine and shown by the second
    /// meter: a text the host carries, so showing it costs no render.
    @State private var reading = "20%"

    static let id = "bindingReader"
    static let title = "A binding is no reader"
    static let summary = "One state handed on as `$level`: the meter that reads it is rebuilt, the one shown by an engine is not."

    static let code = """
        @State private var level = 0.2
        @State private var reading = "20%"

        VStack {
            // The knob is handed the state: it drags it, sends it, and follows
            // it with an engine - and reads it at no build.
            Knob(level: $level, reading: $reading)

            // Two meters on the same state. The first READS the value in its
            // body, so every report rebuilds it; the second is handed `$reading`
            // and shows the host's text, and is never rebuilt.
            ReadingMeter(level: $level)
            EngineMeter(reading: $reading)
        }

        private struct Knob: ContentView {
            @Binding var level: Double
            @Binding var reading: String

            var content: Element {
                VStack {
                    Slider($level)
                        .motion(.eased(600, .cubicOut))

                    HStack {
                        Button("Full").onClicked { level = 1 }
                        Button("Empty").onClicked { level = 0 }
                    }
                }
                // Following the state from a child: named, so every report
                // and every frame of a journey wakes it.
                .engine(following: $level) { _ in
                    reading = "\\(Int((level * 100).rounded()))%"
                }
            }
        }

        private struct ReadingMeter: ContentView {
            @Binding var level: Double

            var content: Element {
                let count = debugInfo()          // this view's own build count

                return VStack {
                    // A GET: this meter is a reader, and every report rebuilds it.
                    ProgressBar().progress(level)
                    Label(count)
                }
            }
        }

        private struct EngineMeter: ContentView {
            @Binding var reading: String

            var content: Element {
                let count = debugInfo()          // stays at one

                return VStack {
                    // A BINDING: the host's text, written by the knob's engine.
                    Label().text($reading)
                    Label(count)
                }
            }
        }
        """

    var content: Element {
        VStack {
            Knob(level: $level, reading: $reading)

            ReadingMeter(level: $level)

            EngineMeter(reading: $reading)
        }
        .spacing(18)
    }

    var notes: Element? {
        VStack {
            Label("One state, `level`, handed on as `$level` three times: to the knob, "
                + "which drags it and sends it, and to two meters. Handing it on makes "
                + "nobody a reader - this page's own count stays at one - and what each "
                + "meter costs is decided inside it. The first meter READS `level` to "
                + "set its bar, so every report the thumb makes rebuilds that meter and "
                + "its count climbs; the second is handed `$reading` and shows a text "
                + "the knob's engine writes, and its count stays at one.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("`@Binding` is the same spelling at every depth: in a child, `level` "
                + "is the value and `$level` is the binding again, so `Slider($level)`, "
                + "`following: $level` and `level = 1` are written as the owner writes "
                + "them. Full and Empty are assignments, and the thumb travels under the "
                + "slider's own `.motion`.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("A read in a body is the ONE thing that makes a reader, whether the "
                + "state is the view's own or borrowed. So a value a view must show is "
                + "read where it is shown and costs that view's renders alone, and a "
                + "value that only has to move is handed on and costs none.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}

/// The input, handed the parent's state: drags it, sends it, and follows it
/// with an engine that writes the reading the second meter shows.
private struct Knob: ContentView {
    @Binding var level: Double

    @Binding var reading: String

    var content: Element {
        VStack {
            Slider($level)
                .motion(.eased(600, .cubicOut))

            HStack {
                Button("Full")
                    .backgroundColor(Palette.accent)
                    .cornerRadius(8)
                    .padding(16, 8)
                    .onClicked { level = 1 }

                Button("Empty")
                    .borderColor(Palette.outline)
                    .borderWidth(1)
                    .backgroundColor(.transparent)
                    .textColor(Palette.subtle)
                    .cornerRadius(8)
                    .padding(16, 8)
                    .onClicked { level = 0 }
            }
            .spacing(10)
        }
        .spacing(12)
        .engine(following: $level) { _ in
            reading = "\(Int((level * 100).rounded()))%"
        }
    }
}

/// A meter that READS the value: a reader, rebuilt on every report, and it
/// says so on its own face.
private struct ReadingMeter: ContentView {
    @Binding var level: Double

    var content: Element {
        // Taken before the container, so it is this view's own reading.
        let count = BuildCount.of(debugInfo())

        return VStack {
            ProgressBar()
                .progress(level)
                .progressColor(Palette.accent)

            Label("a bar that reads the value — \(count)")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}

/// A meter handed the host's text: no reader, never rebuilt, and it says so
/// too.
private struct EngineMeter: ContentView {
    @Binding var reading: String

    var content: Element {
        let count = BuildCount.of(debugInfo())

        return VStack {
            Label()
                .text($reading)
                .fontSize(17)

            Label("a text an engine writes — \(count)")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
