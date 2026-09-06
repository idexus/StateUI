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

    static let id = "converters"
    static let title = "Converters"
    static let summary = "`$volume.convert { $0 * 100 }.convertBack { $0 / 100 }` - one state "
        + "in two units, a caption from it, two states into one, and no render for any of it."

    static let code = """
        @State private var volume = 0.2       // 0 to 1
        @State private var celsius = 20.0
        @State private var width = 120.0
        @State private var height = 80.0

        VStack {
            // The source, as it is.
            Slider($volume)

            // THE SAME STATE IN PERCENT: a second state the host carries, worked
            // out by an engine following `volume` - and a drag comes back
            // through `convertBack`, in the source's own terms.
            Slider($volume.convert { $0 * 100 }.convertBack { $0 / 100 })
                .maximum(100)

            // A caption from the conversion: words the host writes.
            Label().text($volume.convert { "\\(Int($0 * 100))%" })

            // Two steppers on one state, in two scales.
            Stepper($celsius)
            Stepper($celsius.convert { $0 * 9 / 5 + 32 }.convertBack { ($0 - 32) * 5 / 9 })

            // TWO STATES INTO ONE: an engine following both.
            Slider($width)
            Slider($height)
            Label().text($width.convert(with: $height) { w, h in "\\(Int(w)) × \\(Int(h)) = \\(Int(w * h))" })
        }
        """

    var example: Element {
        VStack {
            row("1 · the source, 0 to 1 - Slider($volume)") {
                Slider($volume)
                    .minimum(0)
                    .maximum(1)
                    .minimumTrackColor(Palette.accent)
                Label(BuildCount.of(debugInfo()))
                    .fontSize(12)
                    .textColor(Palette.accent)
            }

            row("2 · the same state in percent - Slider($volume.convert { $0 * 100 }.convertBack { $0 / 100 })") {
                Slider($volume.convert { $0 * 100 }.convertBack { $0 / 100 })
                    .minimum(0)
                    .maximum(100)
                    .minimumTrackColor(Palette.subtle)
                Label(BuildCount.of(debugInfo()))
                    .fontSize(12)
                    .textColor(Palette.accent)
            }

            row("3 · a caption from the conversion - Label().text($volume.convert { … })") {
                Label()
                    .text($volume.convert { "\(Int($0 * 100))%" })
                    .fontSize(17)
                Label(BuildCount.of(debugInfo()))
                    .fontSize(12)
                    .textColor(Palette.accent)
            }

            row("4 · one temperature, two scales - Stepper($celsius) and its conversion") {
                HStack {
                    Stepper($celsius)
                        .minimum(-20)
                        .maximum(60)
                    Label()
                        .text($celsius.convert { "\(Int($0)) °C" })
                        .fontSize(15)
                }
                .spacing(10)
                HStack {
                    Stepper($celsius.convert { $0 * 9 / 5 + 32 }.convertBack { ($0 - 32) * 5 / 9 })
                        .minimum(-4)
                        .maximum(140)
                    Label()
                        .text($celsius.convert { "\(Int($0 * 9 / 5 + 32)) °F" })
                        .fontSize(15)
                }
                .spacing(10)
                Label(BuildCount.of(debugInfo()))
                    .fontSize(12)
                    .textColor(Palette.accent)
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
                Label(BuildCount.of(debugInfo()))
                    .fontSize(12)
                    .textColor(Palette.accent)
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
                + "`convert(with:)`. Every row's count stays at one: nothing here reads a "
                + "value at build, so nothing is built again - the arithmetic runs on the "
                + "display's frames and the host wears the answer.")
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
