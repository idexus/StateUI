import StateUI

/// WHO IS THE READER: one state, written by a slider and a button, and seven
/// places it is used - each wearing its own build count, so the rule is on the
/// screen. A get makes the closure it sits in a reader; a binding makes none.
struct ReaderSample: SampleContent {
    /// The one value this page is about. Nothing in this view's own braces
    /// reads it: every get is inside a row, so a write builds that row alone.
    @State private var value = 0.3

    /// A text an engine writes from `value`, for the row that shows it
    /// without reading it.
    @State private var shown = "30%"

    /// An engine's memory, lent to a child by link: written by a button,
    /// read by the child's engine, and never rendered.
    @Memory private var pulses = 0

    static let id = "reader"
    static let title = "Who is the reader"
    static let summary = "One state, seven places it is used, and a build count on each: "
        + "a get makes a reader, a binding makes none."

    static let code = """
        @State private var value = 0.3          // the one value
        @State private var shown = "30%"        // a text an engine writes from it
        @Memory private var pulses = 0          // an engine's memory, lent by link

        VStack {
            // THE WRITERS. A slider handed $value reads nothing at build; a
            // handler reads when it fires, not at build. Neither is a reader.
            Slider($value)
            Button("+10%").onClicked { value = min(1, value + 0.1) }
            Button("Pulse").onClicked { pulses += 1 }

            // 1. A GET in a container's braces: THIS stack is the reader.
            //    Every write builds its content again - and nothing outside.
            VStack {
                Label("a get: \\(percent(value))")
                DebugInfoLabel()                    // climbs: "N builds, for value"
            }

            // 2. A BINDING alone: a second slider on the same state. The host
            //    moves both thumbs, and this stack is never built again.
            VStack {
                Slider($value)
                DebugInfoLabel()                    // stays: "1 build, first time"
            }

            // 3. A DRIVEN TEXT an engine writes on every write: shown as it
            //    moves, and no reader anywhere.
            VStack {
                Label().text($shown)
                DebugInfoLabel()                    // stays at one
            }

            // 4. A GET in a NESTED container: the inner stack is the reader,
            //    the outer one is not - the count outside the braces stands.
            VStack {
                Label("outside the braces: " + debugInfo())     // stays at one
                VStack {
                    Label("inside: \\(percent(value))")
                    DebugInfoLabel()                            // climbs
                }
            }

            // 5. A CHILD that reads the value it borrowed: the child is the
            //    reader, its count climbs, and this view's does not.
            Reading(value: $value)

            // 6. A CHILD that only hands the binding on: never built again.
            Holding(value: $value)

            // 7. MEMORY BY LINK: the child's engine reads `pulses` through the
            //    link and so follows it. Pulse wakes the engine, which writes a
            //    driven text - no render on either side.
            Pulsed(pulses: $pulses)
        }
        .engine(following: $value) { _ in
            shown = percent(value)
        }

        private struct Reading: ContentView {
            @Binding var value: Double

            var content: Element {
                VStack {
                    Label("a child that reads: \\(percent(value))")
                    DebugInfoLabel()                            // climbs
                }
            }
        }

        private struct Holding: ContentView {
            @Binding var value: Double

            var content: Element {
                VStack {
                    Slider($value)
                    DebugInfoLabel()                            // stays at one
                }
            }
        }

        private struct Pulsed: ContentView {
            @Link var pulses: Int
            @State private var said = "pulses · 0"

            var content: Element {
                VStack {
                    Label().text($said)
                    DebugInfoLabel()                            // stays at one
                }
                .engine { _ in
                    said = "pulses · \\(pulses)"
                    return .idle
                }
            }
        }
        """

    var content: Element {
        VStack {
            Slider($value)
                .minimum(0)
                .maximum(1)
                .minimumTrackColor(Palette.accent)

            HStack {
                button("+10%") { value = min(1, value + 0.1) }
                button("Pulse") { pulses += 1 }
            }
            .spacing(8)
            .horizontalOptions(.center)

            row("1 · a get in this row's braces - the row is the reader") {
                Label("value · \(percent(value))")
                    .fontSize(15)
                DebugInfoLabel()
            }

            row("2 · a binding alone - the host moves both thumbs, nothing is rebuilt") {
                Slider($value)
                    .minimum(0)
                    .maximum(1)
                    .minimumTrackColor(Palette.subtle)
                DebugInfoLabel()
            }

            row("3 · a driven text an engine writes - shown as it moves, no reader") {
                Label()
                    .text($shown)
                    .fontSize(15)
                DebugInfoLabel()
            }

            row("4 · a get in a NESTED container - the inner one is the reader") {
                Label("outside the braces: " + BuildCount.of(debugInfo()))
                    .fontSize(12)
                    .textColor(Palette.accent)
                Border {
                    VStack {
                        Label("inside: \(percent(value))")
                            .fontSize(15)
                        DebugInfoLabel()
                    }
                    .spacing(4)
                }
                .padding(8)
                .strokeShape(.roundRectangle(6))
                .stroke(Palette.outline)
            }

            Reading(value: $value)

            Holding(value: $value)

            Pulsed(pulses: $pulses)
        }
        .spacing(10)
        .engine(following: $value) { _ in
            shown = percent(value)
        }
    }

    var notes: Element? {
        VStack {
            Label("One state, `value`, written by the slider at the top and by +10%. "
                + "Every row is a closure of its own and takes its own reading, so "
                + "what a write costs is on the screen: the rows that READ the value - "
                + "a get in their braces - are built again on every write, and the rows "
                + "that are only handed `$value` are not. `DebugInfoLabel` is this "
                + "gallery's one-liner over the library's own `debugInfo()`, and where "
                + "it is written is what it measures.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("THAT IS THE WHOLE RULE. A get makes the closure it sits in a reader, "
                + "and a write builds exactly that closure again - the inner stack in "
                + "row 4, and not the row around it. A binding makes no reader: handed "
                + "to a control, a child or an engine, the host carries the value on its "
                + "own frames and renders nobody for it. A handler is not a reader "
                + "either: it reads when it fires, not at build.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Pulse writes a `@Memory`, lent to the last row by `$pulses`. The row's "
                + "engine reads it through the `@Link`, which is what makes the engine "
                + "follow it: the write wakes the engine, the engine writes a driven "
                + "text, and neither side renders - the count stays at one while the "
                + "number climbs.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }

    /// One row: a caption, then the content in a stack of its own - so the
    /// reading taken inside the content is that stack's and nobody else's,
    /// and the caption around it is never built again.
    private func row(_ caption: String, @ViewBuilder _ content: @escaping () -> [Element]) -> Element {
        Border {
            VStack {
                Label(caption)
                    .fontSize(11)
                    .textColor(Palette.subtle)

                VStack(content: content)
                    .spacing(4)
            }
            .spacing(6)
        }
        .padding(10)
        .strokeShape(.roundRectangle(8))
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
            .padding(14, 6)
            .onClicked(act)
    }
}

/// A child that READS the value it borrowed: a reader, built again on every
/// write, and it says so.
private struct Reading: ContentView {
    @Binding var value: Double

    var content: Element {
        Border {
            VStack {
                Label("5 · a child that reads the value it borrowed - the child is the reader")
                    .fontSize(11)
                    .textColor(Palette.subtle)
                Label("value · \(percent(value))")
                    .fontSize(15)
                DebugInfoLabel()
            }
            .spacing(4)
        }
        .padding(10)
        .strokeShape(.roundRectangle(8))
        .stroke(Palette.outline)
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}

/// A child that only hands the binding on: no reader, never built again.
private struct Holding: ContentView {
    @Binding var value: Double

    var content: Element {
        Border {
            VStack {
                Label("6 · a child that only hands the binding on - never built again")
                    .fontSize(11)
                    .textColor(Palette.subtle)
                Slider($value)
                    .minimum(0)
                    .maximum(1)
                    .minimumTrackColor(Palette.subtle)
                DebugInfoLabel()
            }
            .spacing(4)
        }
        .padding(10)
        .strokeShape(.roundRectangle(8))
        .stroke(Palette.outline)
    }
}

/// A child on the parent's memory by LINK: its engine reads the memory and so
/// follows it, and shows what it read as a driven text.
private struct Pulsed: ContentView {
    @Link var pulses: Int

    @State private var said = "pulses · 0"

    var content: Element {
        Border {
            VStack {
                Label("7 · a memory by link - the engine follows it, and nobody renders")
                    .fontSize(11)
                    .textColor(Palette.subtle)
                Label()
                    .text($said)
                    .fontSize(15)
                DebugInfoLabel()
            }
            .spacing(4)
        }
        .padding(10)
        .strokeShape(.roundRectangle(8))
        .stroke(Palette.outline)
        .engine { _ in
            said = "pulses · \(pulses)"
            return .idle
        }
    }
}
