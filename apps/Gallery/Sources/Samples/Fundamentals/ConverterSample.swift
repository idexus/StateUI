import StateUI

/// A BINDING CONVERTED ON ITS WAY TO A CONTROL: one state shown in two units,
/// a caption worked out from it, two states worked into one - each result
/// worked out from where its sources are going, with nothing built for any of
/// it.
struct ConverterSample: SampleContent, ExampleContent {
    // listing: ConverterSample
    /// The one value the first three rows are about, in 0 to 1.
    @State private var volume = 0.2

    /// A temperature, kept in Celsius and shown in both scales.
    @State private var celsius = 20.0

    /// Two sides of a rectangle, worked into its area.
    @State private var width = 120.0

    @State private var height = 80.0

    /// What the seventh row calls the rectangle - a third source, and a text
    /// among the numbers.
    @State private var named = "panel"

    /// How many cells, and how wide each: the last row's bar is as wide as
    /// both together.
    @State private var columns = 2.0

    @State private var cell = 80.0
    // listing: end

    static let id = "converters"
    static let title = "Converters"
    static let summary = "`convert` and its way back: one state in two units, a caption from it, and no render."

    // listing: ConverterSample
    var body: some View {
        // Every row is a closure of its own, and every one of them takes
        // its own reading - which is how you see that NONE of them is ever
        // built again: nothing here reads a value, it is all bindings.
        VStack {
            row("1 · the source, 0 to 1") {
                // The source, as it is.
                Slider($volume)
                    .accessibilityIdentifier("converters.volume")
                    .accessibilityLabel("Volume, 0 to 1")
                    .minimum(0)
                    .maximum(1)
                    .tint(Palette.accent)
                DebugInfoLabel()
            }

            row("2 · the same state in percent") {
                // THE SAME STATE IN PERCENT: a second state the host carries,
                // worked out from `volume` whenever it is written - and a drag
                // comes back through `back`, in the source's own terms and type.
                Slider($volume.convert { $0 * 100 } back: { $0 / 100 })
                    .accessibilityIdentifier("converters.volume.percent")
                    .accessibilityLabel("Volume, in percent")
                    .minimum(0)
                    .maximum(100)
                    .tint(Palette.subtle)
                DebugInfoLabel()
            }

            row("3 · a caption from the conversion") {
                // A caption from the conversion: words the host writes.
                Text($volume.convert { "\(Int(($0 * 100).rounded()))%" })
                    .fontSize(17)
                DebugInfoLabel()
            }

            row("4 · one temperature, two scales") {
                // TWO STEPPERS ON ONE STATE, IN TWO SCALES - and the steps are
                // what keep the two captions honest: 5 °C IS 9 °F, exactly, and
                // the ends line up too (-20 °C = -4 °F, 60 °C = 140 °F), so
                // every value either stepper can reach is a whole number in
                // both. A step of one on each would leave the state on 20.56
                // and the two captions would round it their own way.
                HStack {
                    Stepper($celsius)
                        .accessibilityIdentifier("converters.celsius")
                        .accessibilityLabel("Celsius")
                        .step(5)
                        .minimum(-20)
                        .maximum(60)
                    Text($celsius.convert { "\(Int($0)) °C" })
                        .fontSize(15)
                }
                .spacing(10)
                HStack {
                    Stepper($celsius.convert { $0 * 9 / 5 + 32 } back: { ($0 - 32) * 5 / 9 })
                        .accessibilityIdentifier("converters.fahrenheit")
                        .accessibilityLabel("Fahrenheit")
                        .step(9)
                        .minimum(-4)
                        .maximum(140)
                    Text($celsius.convert { "\(Int($0 * 9 / 5 + 32)) °F" })
                        .fontSize(15)
                }
                .spacing(10)
                DebugInfoLabel()
            }

            row("5 · two states into one") {
                // TWO STATES INTO ONE: an engine following both.
                Slider($width)
                    .accessibilityIdentifier("converters.width")
                    .accessibilityLabel("Width")
                    .minimum(20)
                    .maximum(200)
                Slider($height)
                    .accessibilityIdentifier("converters.height")
                    .accessibilityLabel("Height")
                    .minimum(20)
                    .maximum(200)
                // The sides as they are shown, whole, and their product - not the product of what
                // the sliders hold, which would disagree with the sides it names.
                Text(.multi($width, $height).convert { w, h in
                    let (across, down) = (Int(w.rounded()), Int(h.rounded()))
                    return "\(across) × \(down) = \(across * down)"
                })
                    .fontSize(17)
                DebugInfoLabel()
            }

            row("6 · a field is handed the state") {
                // A FIELD IS HANDED THE STATE TOO: `TextField($named)` reads nothing
                // at build, and what is typed lands on `named` as the host's
                // own write - so this row stays at one as well.
                TextField($named)
                    .accessibilityIdentifier("converters.named")
                    .accessibilityLabel("A name for it")
                    .placeholder("Call it something")
                DebugInfoLabel()
            }

            row("7 · as many as you like") {
                // AS MANY AS YOU LIKE: `.multi` names the states and `convert`
                // is the arithmetic over them, in the order they were named -
                // two to ten of them, of any types the host carries. Nothing
                // is read here, so typing above rewrites this caption without
                // building it.
                Text(.multi($named, $width, $height)
                        .convert { "\($0): \(Int($1.rounded())) × \(Int($2.rounded()))" })
                    .fontSize(17)
                DebugInfoLabel()
            }

            row("8 · a result with a motion of its own") {
                // TWO SOURCES, ONE RESULT, ITS OWN MOTION: the bar's width is
                // where both are GOING, multiplied - worked out once a write -
                // and it travels there on a spring that is the result's alone.
                // The sources are plain numbers: nothing animates them.
                Rectangle()
                    .fill(Palette.accent)
                    .height(12)
                    .cornerRadius(6)
                    .width(Binding<Double>.multi($columns, $cell).convert({ $0 * $1 }, motion: .spring()))
                    .horizontalAlignment(.start)
                    .accessibilityIdentifier("converters.bar")
                // The same result with no motion: the destination, at once.
                Text(.multi($columns, $cell).convert { "going to \(Int($0 * $1))" })
                    .accessibilityIdentifier("converters.going")
                    .fontSize(15)
                Button("Change both")
                    .accessibilityIdentifier("converters.both")
                    .onClicked {
                        // One handler, two writes: the result is worked out once, from both.
                        (columns, cell) = columns == 2 ? (3, 100) : (2, 80)
                    }
                DebugInfoLabel()
            }
        }
        .spacing(10)
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("`$volume.convert { $0 * 100 }` is a second state the host carries, worked "
                + "out from where the first is going whenever it is written: drag either "
                + "slider and the other follows, because `back` lands what the user did to "
                + "the result on the source, in the source's own terms. "
                + "The caption under them is words converted from the same state.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Two steppers on one Celsius state, one of them converted to Fahrenheit "
                + "and back; two sliders worked into one caption with "
                + "`.multi($width, $height)`, which takes as many states as you like - two "
                + "to ten, of any types, the closure taking them in the order they were "
                + "named, as `.multi($named, $width, $height)` does. Every count here stays at one, the "
                + "field's included: `TextField($named)` hands the state to the host as a "
                + "caption does, so what is typed lands on `named` with no render - type "
                + "in the field and watch the `.multi` caption in the next row follow "
                + "while every count stands still.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("The temperature steps by 5 and by 9 on purpose, and it is the one "
                + "thing to copy from that row. A conversion is exact; a value shown is "
                + "rounded, and two scales round the same number their own way - step "
                + "by one on each and the state lands on 20.56, where one caption says "
                + "20 °C and the other says 69 °F, which no single temperature is. "
                + "5 °C is 9 °F exactly, and the ends line up too, so every value either "
                + "stepper can reach is whole in both. Where no such step exists, show "
                + "the value with enough figures to be true rather than rounding it "
                + "twice.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("`back` is meant to be the inverse of the conversion. What the user does "
                + "to a control lands on the source through it, once, and the control then "
                + "shows what the conversion makes of that source; a frame of an animation "
                + "never goes back. A conversion with no `back` is read-only.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("The last row's bar is a result too: its width is where both sources are "
                + "going, multiplied, and `motion: .spring()` is the result's own motion. "
                + "Press Change both: the two writes work the result out once, the bar makes "
                + "one journey to it, and the caption - the same result with no motion - "
                + "says where it is going at once. A conversion never follows a source "
                + "frame by frame; a value that must is written by an engine following a "
                + "journey, as Reading a driven state shows.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }

    // listing: ConverterSample
    /// One row: a caption, then the content in a stack of its own, so the
    /// reading taken inside the content is that stack's alone.
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
        .style(.card)
        .padding(10)
        .shape(.roundedRectangle(8))
        .stroke(Palette.outline)
    }
    // listing: end
}
