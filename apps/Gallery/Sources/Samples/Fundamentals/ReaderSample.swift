import StateUI

/// WHO IS THE READER: seven ways to use a state - each wearing its own build
/// count, so the rule is on the screen. A get makes the closure it sits in a
/// reader; a binding makes none.
struct ReaderSample: SampleContent, ExampleContent {
    // listing: ReaderSample
    /// The one value this page is about. Nothing in this view's own braces
    /// reads it: every get is inside a row, so a write builds the closures that
    /// read it and nothing around them.
    @State private var value = 0.3   // the one value

    /// A state no view reads, lent to a child as `$pulses`: written by a
    /// button, followed by the child's engine, and never rendered.
    @State private var pulses = 0   // read by no view, followed by an engine
    // listing: end

    static let id = "reader"
    static let title = "Who is the reader"
    static let summary = "Seven ways to use a state: a get makes a reader, a binding makes none."

    // listing: ReaderSample
    var body: some View {
        // This stack reads nothing: each numbered row below is a closure of
        // its own, with its own reading.
        VStack {
            // THE WRITERS. A slider handed $value reads nothing at build; a
            // handler reads when it fires, not at build. Neither is a reader.
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

            // 1. A STATE BY BINDING: the child's engine follows `pulses` through
            //    the binding it was handed. Pulse wakes the engine, which writes
            //    a driven text - no render on either side.
            Pulsed(pulses: $pulses)

            row("2 · a get in this row's braces") {
                Text("value · \(percent(value))")
                    .fontSize(15)
                DebugInfoLabel()   // climbs: "N builds, for value"
            }

            row("3 · a binding alone") {
                Slider($value)
                    .accessibilityIdentifier("reader.value.bound")
                    .accessibilityLabel("Value, handed on as a binding")
                    .minimum(0)
                    .maximum(1)
                    .tint(Palette.subtle)
                DebugInfoLabel()   // stays: "1 build, first time"
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

            // 6. A CHILD that reads the value it borrowed: the child is the
            //    reader, its count climbs, and this view's does not.
            Reading(value: $value)

            // 7. A CHILD that only hands the binding on: never built again.
            Holding(value: $value)
        }
        .spacing(10)
    }
    // listing: end

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

            Text("A binding makes no reader: handing `$value` to a control, a child or an "
                + "engine reads nothing, and the host carries a control's value on its own "
                + "frames with nobody built for it. Row 3 is a second slider on `$value`, "
                + "and the host moves both thumbs; row 4 shows the value through a "
                + "conversion without reading it; the child in row 7 only hands the "
                + "binding on. None of them is built again.")
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

    // listing: ReaderSample
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
            .onClicked(act)
    }
    // listing: end
}

// listing: ReaderSample
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
// listing: end

// listing: ReaderSample
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
// listing: end

// listing: ReaderSample
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
// listing: end
