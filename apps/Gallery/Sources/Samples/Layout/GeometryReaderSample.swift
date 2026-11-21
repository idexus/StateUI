import StateUI

/// Content built from the space it was given, and frames reported on request.
struct GeometryReaderSample: SampleContent, ExampleContent {
    // listing: GeometryReaderSample
    @State private var slot = Rect(x: 0, y: 0, width: 0, height: 0)
    @State private var window = Rect(x: 0, y: 0, width: 0, height: 0)
    @State private var safe = Rect(x: 0, y: 0, width: 0, height: 0)

    @State private var width = 220.0

    // The rectangle fed into a state: the first, or the second while the
    // switch says so. A state handed over reads it as it is handed over.
    @State private var first = Rect(x: 0, y: 0, width: 0, height: 0)
    @State private var second = Rect(x: 0, y: 0, width: 0, height: 0)
    @State private var feedsSecond = false
    // listing: end

    static let id = "geometryReader"
    static let title = "Measuring a frame"
    static let summary = "GeometryReader builds from its measured frame; `.onFrameChanged` reports any view's."

    var examples: [Example] {
        [Example(self), Example(FrameStages())]
    }

    // listing: GeometryReaderSample
    var body: some View {
        VStack {
            // `slot`, `window` and `safe` are read in these braces - the three
            // lines below print all of them - so every frame report builds
            // this closure, which is the whole cost of watching a frame.
            DebugInfoLabel()

            // THE PARENT, DRAWN in a gentle tint, because `slot` below is
            // measured against THIS box and the numbers say nothing until
            // there is something on the screen for them to be relative to.
            // It fills the page's width, so narrowing the panel walks its x
            // in towards the middle.
            VStack {
                Text("the parent")
                    .fontSize(11)
                    .textColor(Palette.brand)

                // The reader's content is built FROM the measurement, which
                // is the reader's own @State. The three handlers write the
                // page's states instead, and the three lines below print
                // them - so a settled frame builds the reader AND the page.
                GeometryReader { frame in
                    Text("\(Int(frame.width)) × \(Int(frame.height))")
                        .fontSize(22)
                        .fontWeight(.bold)
                        .textColor(Palette.onAccent)
                        .horizontalAlignment(.center)
                        .verticalAlignment(.center)
                }
                // Driven: the host carries the width, and no render
                // describes it.
                .width($width)
                .height(120)
                .background(Palette.accent)
                .horizontalAlignment(.center)
                // Reporting is a modifier on ANY view - one handler per
                // space. Nothing is measured unless something asks: a view
                // without a handler is not even subscribed.
                .onFrameChanged { slot = $0 }
                .onFrameChanged(in: .global) { window = $0 }
                .onFrameChanged(in: .safeArea) { safe = $0 }
                // Fed one way into a state, with no handler; the text below
                // reads it, so a new size renders this view.
                .frame(into: feedsSecond ? $second : $first)
            }
            .spacing(8)
            .padding(16)
            .background(Palette.selected)

            Slider($width)
                .accessibilityIdentifier("frameReader.width")
                .accessibilityLabel("Width")
                .minimum(140)
                .maximum(340)

            Switch("Feed the rectangle into the second state", isOn: $feedsSecond)
                .accessibilityIdentifier("frameReader.second")

            Text("first · \(Int(first.width)) × \(Int(first.height))     second · \(Int(second.width)) × \(Int(second.height))")
                .fontSize(13)
                .horizontalTextAlignment(.center)

            // Where the panel sits, in three spaces. The first is against the
            // tinted box above, which is why that box is drawn at all.
            Text("in its parent · \(Int(slot.x)), \(Int(slot.y))")
                .fontSize(13)
                .textColor(Palette.brand)
                .horizontalTextAlignment(.center)

            Text("in the window · \(Int(window.x)), \(Int(window.y))")
                .fontSize(13)
                .horizontalTextAlignment(.center)

            Text("in the safe area · \(Int(safe.x)), \(Int(safe.y))")
                .fontSize(13)
                .horizontalTextAlignment(.center)

            Button("Animate the width")
                .horizontalAlignment(.center)
                .onClicked {
                    // The width describes nothing: the host carries the width and
                    // the slider's thumb off the same state, and the frame reports
                    // say where the panel actually got to.
                    $width.journey.move(to: width < 240 ? 340 : 140)
                }
        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("The tinted box is the parent, drawn because the first reading is measured "
                + "against it: `in its parent` is where the panel sits inside that box. "
                + "Narrowing the panel walks its x in towards the middle, while the window "
                + "and safe-area readings move by the same amount from wherever the page is.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("A frame costs nothing until something asks for it: a view with no "
                + "`.onFrameChanged` is not even subscribed. A report comes when the frame "
                + "settles somewhere new, so dragging the slider re-lays the panel out and "
                + "the button's walk reports every step of the way.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("The panel's width and the slider's thumb are one driven state - "
                + "`.width($width)` and `Slider($width)` - so dragging the thumb "
                + "resizes the panel without the page being described for it, and the "
                + "button moves that same state.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("A state handed to `.frame` reads the rectangle as it is handed over: feed the second "
                + "state while nothing moves, and it says the panel's size at once.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("The width costs no build - a driven state describes nothing by itself - "
                + "but the measurement does. The reader builds its content from the frame "
                + "it was given, and the three handlers beside it write the page's own "
                + "states, which the lines under the panel print. So the page is a reader "
                + "too, and the count at the top moves for the frame reports and nothing else.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}

/// A view's two rectangles: where its layout puts it, and the rectangle
/// around what is drawn of it.
struct FrameStages: ExampleContent {
    // listing: FrameStages
    @State private var placed = Rect(x: 0, y: 0, width: 0, height: 0)
    @State private var drawn = Rect(x: 0, y: 0, width: 0, height: 0)

    @State private var larger = false
    @State private var far = false

    // THE SAME VIEW, ASKED ONCE through its aim: both rectangles, and how
    // it is drawn at that moment.
    @Aim(Rectangle.self) private var card
    @State private var asked = "asked · -"

    var body: some View {
        VStack {
            VStack {
                Rectangle()
                    .fill(Palette.accent)
                    .cornerRadius(8)
                    .width(80)
                    .height(48)
                    // A TRANSFORM: it moves what is drawn, never the layout.
                    .scale(larger ? 1.4 : 1)
                    // THE LAYOUT'S OWN: the stack carries the card across.
                    .horizontalAlignment(far ? .end : .start)
                    // ONE VIEW, TWO RECTANGLES, a state each: where its layout
                    // puts it, and the rectangle around what is drawn of it.
                    .frame(into: $placed)
                    .frame(into: $drawn, stage: .presentation)
                    .aim(card)
                    .accessibilityIdentifier("stages.card")
            }
            // Slow enough to read the numbers on the way.
            .motion(.eased(.milliseconds(1200)))
            .padding(24)
            .background(Palette.selected)

            SwitchRow("Larger", $larger)
            SwitchRow("At the far end", $far)

            Text("layout · \(Self.words(placed))")
                .accessibilityIdentifier("stages.layout")
                .fontSize(13)
                .horizontalTextAlignment(.center)

            Text("drawn · \(Self.words(drawn))")
                .accessibilityIdentifier("stages.drawn")
                .fontSize(13)
                .textColor(Palette.brand)
                .horizontalTextAlignment(.center)

            // ONE READING, where the two above follow: pressed while the
            // card moves, it says where the movement has got it to.
            Button("Ask once").onClicked(policy: .ignoreWhileRunning) {
                let sample = try await card.presentationSample()
                asked = "asked · \(Self.words(sample.frame)) at \(Int((sample.scaleX * 100).rounded()))%"
            }
            .accessibilityIdentifier("stages.ask")

            Text(asked)
                .accessibilityIdentifier("stages.asked")
                .fontSize(13)
                .horizontalTextAlignment(.center)
        }
        .spacing(12)
    }

    /// A rectangle in whole points: its corner, then its size.
    static func words(_ rect: Rect) -> String {
        "\(Int(rect.x.rounded())), \(Int(rect.y.rounded())) · \(Int(rect.width.rounded())) × \(Int(rect.height.rounded()))"
    }
    // listing: end

    var notes: (any View)? {
        Text("Turn Larger on: the card grows and `drawn` grows with it, while `layout` stands. Turn At the far "
            + "end on: `layout` says the far end at once, and `drawn` counts the way there. Ask once reads "
            + "the card through its aim, at the moment it is pressed.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
