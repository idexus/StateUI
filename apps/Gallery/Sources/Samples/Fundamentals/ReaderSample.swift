import StateUI

/// WHO IS THE READER: one state, written by a slider and a button, and seven
/// places it is used - each wearing its own build count, so the rule is on the
/// screen. A get makes the closure it sits in a reader; a binding makes none.
struct ReaderSample: SampleContent, ExampleContent {
    /// The one value this page is about. Nothing in this view's own braces
    /// reads it: every get is inside a row, so a write builds that row alone.
    @State private var value = 0.3

    /// A state no view reads, lent to a child as `$pulses`: written by a
    /// button, followed by the child's engine, and never rendered.
    @State private var pulses = 0

    static let id = "reader"
    static let title = "Who is the reader"
    static let summary = "One state used in seven places: a get makes a reader, a binding makes none."

    static let code = """
        @State private var value = 0.3          // the one value
        @State private var pulses = 0           // read by no view, followed by an engine

        VStack {
            // THE WRITERS. A slider handed $value reads nothing at build; a
            // handler reads when it fires, not at build. Neither is a reader.
            Slider($value)
            Button("+10%").onClicked { value = min(1, value + 0.1) }
            Button("Pulse").onClicked { pulses += 1 }

            // 1. A STATE BY BINDING: the child's engine follows `pulses` through
            //    the binding it was handed. Pulse wakes the engine, which writes
            //    a driven text - no render on either side.
            Pulsed(pulses: $pulses)

            // 2. A GET in a container's braces: THIS stack is the reader.
            //    Every write builds its content again - and nothing outside.
            VStack {
                Text("a get: \\(percent(value))")
                DebugInfoLabel()                    // climbs: "N builds, for value"
            }

            // 3. A BINDING alone: a second slider on the same state. The host
            //    moves both thumbs, and this stack is never built again.
            VStack {
                Slider($value)
                DebugInfoLabel()                    // stays: "1 build, first time"
            }

            // 4. A CONVERTED TEXT: the words are the host's own arithmetic
            //    over the state, so this stack shows the value and reads
            //    nothing - a conversion handed on makes no reader.
            VStack {
                Text($value.convert { percent($0) })
                DebugInfoLabel()                    // stays at one
            }

            // 5. A GET in a NESTED container: the inner stack is the reader,
            //    the outer one is not - the count outside the braces stands.
            VStack {
                Text("outside the braces: " + debugInfo())     // stays at one
                VStack {
                    Text("inside: \\(percent(value))")
                    DebugInfoLabel()                            // climbs
                }
            }

            // 6. A CHILD that reads the value it borrowed: the child is the
            //    reader, its count climbs, and this view's does not.
            Reading(value: $value)

            // 7. A CHILD that only hands the binding on: never built again.
            Holding(value: $value)
        }
        private struct Reading: View {
            @Binding var value: Double

            var body: some View {
                VStack {
                    Text("a child that reads: \\(percent(value))")
                    DebugInfoLabel()                            // climbs
                }
            }

            private func percent(_ value: Double) -> String {
                "\\(Int((value * 100).rounded()))%"
            }
        }

        private struct Holding: View {
            @Binding var value: Double

            var body: some View {
                VStack {
                    Slider($value)
                    DebugInfoLabel()                            // stays at one
                }
            }
        }

        private struct Pulsed: View {
            @Binding var pulses: Int
            @State private var said = "pulses · 0"

            var body: some View {
                VStack {
                    Text($said)
                    DebugInfoLabel()                            // stays at one
                }
                .engine(following: $pulses) { _ in
                    said = "pulses · \\(pulses)"
                }
            }
        }

        /// Whole percent, written by hand - a formatter is Foundation.
        private func percent(_ value: Double) -> String {
            "\\(Int((value * 100).rounded()))%"
        }
        """

    var body: some View {
        VStack {
            Slider($value)
                .accessibilityIdentifier("reader.value")
                .accessibilityLabel("Value")
                .minimum(0)
                .maximum(1)
                .tint(Palette.accent)

            HStack {
                button("+10%") { value = min(1, value + 0.1) }
                button("Pulse") { pulses += 1 }
            }
            .spacing(8)
            .horizontalAlignment(.center)

            Pulsed(pulses: $pulses)

            row("2 · a get in this row's braces") {
                Text("value · \(percent(value))")
                    .fontSize(15)
                DebugInfoLabel()
            }

            row("3 · a binding alone") {
                Slider($value)
                    .accessibilityIdentifier("reader.value.bound")
                    .accessibilityLabel("Value, handed on as a binding")
                    .minimum(0)
                    .maximum(1)
                    .tint(Palette.subtle)
                DebugInfoLabel()
            }

            row("4 · a converted text") {
                Text()
                    .text($value.convert { percent($0) })
                    .fontSize(15)
                DebugInfoLabel()
            }

            row("5 · a get in a nested container") {
                Text("outside the braces: " + BuildCount.of(debugInfo()))
                    .fontSize(12)
                    .textColor(Palette.accent)
                ZStack {
                    VStack {
                        Text("inside: \(percent(value))")
                            .fontSize(15)
                        DebugInfoLabel()
                    }
                    .spacing(4)
                }
                .style("Card")
                .padding(8)
                .shape(.roundedRectangle(6))
                .stroke(Palette.outline)
            }

            Reading(value: $value)

            Holding(value: $value)
        }
        .spacing(10)
    }

    var notes: (any View)? {
        VStack {
            Text("One state, `value`, written by the slider at the top and by +10%. "
                + "Every row is a closure of its own and takes its own reading, so "
                + "what a write costs is on the screen. `DebugInfoLabel` is this "
                + "gallery's one-liner over the library's own `debugInfo()`, and where "
                + "it is written is what it measures.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("A get makes the closure it sits in a reader, and a write builds exactly "
                + "that closure again: row 2, the inner stack in row 5 and not the row "
                + "around it, and the child in row 6, which reads the value it borrowed. "
                + "A handler is not a reader: it reads when it fires, not at build.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("A binding makes no reader. Handed to a control, a child or an engine, "
                + "the host carries the value on its own frames and renders nobody for it. "
                + "Row 3 is a second slider on `$value`, and the host moves both thumbs; "
                + "row 4 shows the value through a conversion without reading it; the "
                + "child in row 7 only hands the binding on. None of them is built again.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Pulse writes a state no view reads, lent to the first row by `$pulses`. "
                + "The row's engine names it in `following:`, which is what makes the "
                + "engine follow it: the write wakes the engine, the engine writes a "
                + "driven text, and neither side renders - the count stays at one while "
                + "the number climbs.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }

    /// One row: a caption, then the content in a stack of its own - so the
    /// reading taken inside the content is that stack's and nobody else's,
    /// and the caption around it is never built again.
    private func row<Content: Views>(_ caption: String, @ViewBuilder _ content: @escaping () -> Content) -> some View {
        ZStack {
            VStack {
                Text(caption)
                    .fontSize(11)
                    .textColor(Palette.subtle)

                VStack(content: content)
                    .spacing(4)
            }
            .spacing(6)
        }
        .style("Card")
        .padding(10)
        .shape(.roundedRectangle(8))
        .stroke(Palette.outline)
    }

    /// Whole percent, written by hand - a formatter is Foundation.
    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    /// One of the buttons, all of which look the same.
    private func button(_ caption: String, _ act: @escaping EventHandler) -> Button {
        Button(caption)
            .fontSize(13)
            .padding(horizontal: 14, vertical: 6)
            .onClicked(act)
    }
}

/// A child that READS the value it borrowed: a reader, built again on every
/// write, and it says so.
private struct Reading: View {
    @Binding var value: Double

    var body: some View {
        ZStack {
            VStack {
                Text("6 · a child that reads the value it borrowed")
                    .fontSize(11)
                    .textColor(Palette.subtle)
                Text("value · \(percent(value))")
                    .fontSize(15)
                DebugInfoLabel()
            }
            .spacing(4)
        }
        .style("Card")
        .padding(10)
        .shape(.roundedRectangle(8))
        .stroke(Palette.outline)
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}

/// A child that only hands the binding on: no reader, never built again.
private struct Holding: View {
    @Binding var value: Double

    var body: some View {
        ZStack {
            VStack {
                Text("7 · a child that only hands the binding on")
                    .fontSize(11)
                    .textColor(Palette.subtle)
                Slider($value)
                    .accessibilityIdentifier("reader.value.handedOn")
                    .accessibilityLabel("Value, in a child that only hands it on")
                    .minimum(0)
                    .maximum(1)
                    .tint(Palette.subtle)
                DebugInfoLabel()
            }
            .spacing(4)
        }
        .style("Card")
        .padding(10)
        .shape(.roundedRectangle(8))
        .stroke(Palette.outline)
    }
}

/// A child on the parent's state by BINDING: its engine follows the state it
/// was handed, and shows what it read as a driven text.
private struct Pulsed: View {
    @Binding var pulses: Int

    @State private var said = "pulses · 0"

    var body: some View {
        ZStack {
            VStack {
                Text("1 · a state by binding")
                    .fontSize(11)
                    .textColor(Palette.subtle)
                Text()
                    .text($said)
                    .fontSize(15)
                DebugInfoLabel()
            }
            .spacing(4)
        }
        .style("Card")
        .padding(10)
        .shape(.roundedRectangle(8))
        .stroke(Palette.outline)
        .engine(following: $pulses) { _ in
            said = "pulses · \(pulses)"
        }
    }
}
