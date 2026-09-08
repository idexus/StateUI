import StateUI

/// A BINDING CONVERTED ON ITS WAY TO A CONTROL: one state shown in two units,
/// a caption worked out from it, two states worked into one - all by engines
/// the differ writes, on the host's frames, with nothing built for any of it.
struct ConverterSample: SampleContent {
    /// The one value the first three rows are about, in 0 to 1.
    @State private var volume = 0.2

    /// A temperature, kept in Celsius and shown in both scales.
    @State private var celsius = 20.0

    /// Two sides of a rectangle, worked into its area.
    @State private var width = 120.0

    @State private var height = 80.0

    /// What the last row calls the rectangle - a third source, and a text
    /// among the numbers.
    @State private var named = "panel"

    static let id = "converters"
    static let title = "Converters"
    static let summary = "`$volume.convert { $0 * 100 }.convertBack { $0 / 100 }` - one state "
        + "in two units, a caption from it, several states into one, and no render for any of it."

    static let code = """
        @State private var volume = 0.2       // 0 to 1
        @State private var celsius = 20.0
        @State private var width = 120.0
        @State private var height = 80.0
        @State private var named = "panel"

        VStack {
            // Every row is a closure of its own, and every one of them takes
            // its own reading - which is how you see that NONE of them is ever
            // built again: nothing here reads a value, it is all bindings.
            VStack {
                // The source, as it is.
                Slider($volume)
                DebugInfoLabel()                  // stays at one
            }

            VStack {
                // THE SAME STATE IN PERCENT: a second state the host carries,
                // worked out by an engine following `volume` - and a drag comes
                // back through `convertBack`, in the source's own terms.
                Slider($volume.convert { $0 * 100 }.convertBack { $0 / 100 })
                    .maximum(100)
                DebugInfoLabel()                  // stays at one
            }

            VStack {
                // A caption from the conversion: words the host writes.
                Label().text($volume.convert { "\\(Int($0 * 100))%" })
                DebugInfoLabel()                  // stays at one
            }

            VStack {
                // TWO STEPPERS ON ONE STATE, IN TWO SCALES - and the steps are
                // what keep the two captions honest: 5 °C IS 9 °F, exactly, so
                // every value either stepper can reach is a whole number in
                // both. A step of one on each would leave the state on 20.56
                // and the two captions would round it their own way.
                Stepper($celsius)
                    .increment(5)
                Stepper($celsius.convert { $0 * 9 / 5 + 32 }.convertBack { ($0 - 32) * 5 / 9 })
                    .increment(9)
                DebugInfoLabel()                  // stays at one
            }

            VStack {
                // TWO STATES INTO ONE: an engine following both.
                Slider($width)
                Slider($height)
                Label().text($width.convert(with: $height) { w, h in "\\(Int(w)) × \\(Int(h))" })
                DebugInfoLabel()                  // stays at one
            }

            VStack {
                // A FIELD IS HANDED THE STATE TOO: `Entry($named)` reads nothing
                // at build, and what is typed lands on `named` as the host's
                // own write - so this row stays at one as well.
                Entry($named)
                DebugInfoLabel()                  // stays at one
            }

            VStack {
                // AS MANY AS YOU LIKE: `.multi` names the states and `convert`
                // is the arithmetic over them, in the order they were named -
                // two to ten of them, of any types the host carries. Nothing
                // is read here, so typing above rewrites this caption without
                // building it.
                Label().text(.multi($named, $width, $height)
                    .convert { "\\($0): \\(Int($1)) × \\(Int($2))" })
                DebugInfoLabel()                  // stays at one
            }
        }
        """

    var content: Element {
        VStack {
            row("1 · the source, 0 to 1 - Slider($volume)") {
                Slider($volume)
                    .minimum(0)
                    .maximum(1)
                    .minimumTrackColor(Palette.accent)
                DebugInfoLabel()
            }

            row("2 · the same state in percent - Slider($volume.convert { $0 * 100 }.convertBack { $0 / 100 })") {
                Slider($volume.convert { $0 * 100 }.convertBack { $0 / 100 })
                    .minimum(0)
                    .maximum(100)
                    .minimumTrackColor(Palette.subtle)
                DebugInfoLabel()
            }

            row("3 · a caption from the conversion - Label().text($volume.convert { … })") {
                Label()
                    .text($volume.convert { "\(Int($0 * 100))%" })
                    .fontSize(17)
                DebugInfoLabel()
            }

            row("4 · one temperature, two scales - Stepper($celsius) and its conversion") {
                HStack {
                    // 5 °C IS 9 °F EXACTLY, and the ends line up too
                    // (-20 °C = -4 °F, 60 °C = 140 °F), so every value either
                    // stepper can reach is whole in both scales and the two
                    // captions can never disagree.
                    Stepper($celsius)
                        .increment(5)
                        .minimum(-20)
                        .maximum(60)
                    Label()
                        .text($celsius.convert { "\(Int($0)) °C" })
                        .fontSize(15)
                }
                .spacing(10)
                HStack {
                    Stepper($celsius.convert { $0 * 9 / 5 + 32 }.convertBack { ($0 - 32) * 5 / 9 })
                        .increment(9)
                        .minimum(-4)
                        .maximum(140)
                    Label()
                        .text($celsius.convert { "\(Int($0 * 9 / 5 + 32)) °F" })
                        .fontSize(15)
                }
                .spacing(10)
                DebugInfoLabel()
            }

            row("5 · two states into one - $width.convert(with: $height) { w, h in … }") {
                Slider($width)
                    .minimum(20)
                    .maximum(200)
                Slider($height)
                    .minimum(20)
                    .maximum(200)
                Label()
                    .text($width.convert(with: $height) { w, h in "\(Int(w)) × \(Int(h)) = \(Int(w * h))" })
                    .fontSize(17)
                DebugInfoLabel()
            }

            row("6 · a field is handed the state - Entry($named) reads nothing, typing lands on it") {
                Entry($named)
                    .placeholder("Call it something")
                DebugInfoLabel()
            }

            row("7 · as many as you like - .multi($named, $width, $height).convert { … }") {
                Label()
                    .text(.multi($named, $width, $height)
                        .convert { "\($0): \(Int($1)) × \(Int($2))" })
                    .fontSize(17)
                DebugInfoLabel()
            }
        }
        .spacing(10)
    }

    var notes: Element? {
        VStack {
            Label("`$volume.convert { $0 * 100 }` is a second state the host carries, worked "
                + "out from the first by an engine the differ writes for you: drag either "
                + "slider and the other follows, because `convertBack` is the engine the "
                + "other way, landing a report on the source in the source's own terms. "
                + "The caption under them is words written from the same conversion.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Two steppers on one Celsius state, one of them converted to Fahrenheit "
                + "and back; two sliders worked into one caption with "
                + "`convert(with:)`; and `.multi($named, $width, $height)` for as many "
                + "states as you like - two to ten, of any types, the closure taking them "
                + "in the order they were named. Every count here stays at one, the "
                + "field's included: `Entry($named)` hands the state to the host as a "
                + "caption does, so what is typed lands on `named` with no render - type "
                + "in the field and watch the `.multi` caption in the next row follow "
                + "while every count stands still.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("THE TEMPERATURE STEPS BY 5 AND BY 9 ON PURPOSE, and it is the one "
                + "thing to copy from that row. A conversion is exact; a value SHOWN is "
                + "rounded, and two scales round the same number their own way - step "
                + "by one on each and the state lands on 20.56, where one caption says "
                + "21 °C and the other says 69 °F, which no single temperature is. "
                + "5 °C is 9 °F exactly, and the ends line up too, so every value either "
                + "stepper can reach is whole in both. Where no such step exists, show "
                + "the value with enough figures to be true rather than rounding it "
                + "twice.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("A conversion written once is one state across renders - kept on its "
                + "source under the line that wrote it - so the control the host ties "
                + "keeps its number. `convertBack` is meant to be the inverse of "
                + "`convert`; where it is not exactly, the source settles once on the "
                + "value the round trip lands on.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }

    /// One row: a caption, then the content in a stack of its own, so the
    /// reading taken inside the content is that stack's alone.
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
}
