import StateUI

/// Content built from the space it was given, and frames reported on request.
struct GeometryReaderSample: SampleContent, ExampleContent {
    @State private var slot = Rect(0, 0, 0, 0)
    @State private var window = Rect(0, 0, 0, 0)
    @State private var safe = Rect(0, 0, 0, 0)

    @State private var width = 220.0

    static let id = "geometryReader"
    static let title = "Measuring a frame"
    static let summary = "GeometryReader builds from its measured frame; `.onFrameChanged` reports any view's."

    static let code = """
        @State private var width = 220.0
        @State private var slot = Rect(0, 0, 0, 0)
        @State private var window = Rect(0, 0, 0, 0)
        @State private var safe = Rect(0, 0, 0, 0)

        VStack {
            // `slot`, `window` and `safe` are read in these braces - the three
            // lines below print all of them - so every frame report builds
            // this closure, which is the whole cost of watching a frame.
            DebugInfoLabel()

            // THE PARENT, DRAWN in a gentle tint, because `slot` below is
            // measured against THIS box and the numbers say nothing until
            // there is something on the screen for them to be relative to.
            // It fills the page's width, so widening the panel walks its x
            // in towards the middle.
            VStack {
                Text("the parent")

                // The reader's content is built FROM the measurement, which
                // is the reader's own @State. The three handlers write the
                // page's states instead, and the lines below print them - so
                // a settled frame builds the reader AND the page's braces.
                GeometryReader { frame in
                    Text("\\(Int(frame.width)) × \\(Int(frame.height))")
                }
                // Driven: the host carries the width, and no render
                // describes it.
                .width($width)
                .height(120)
                .horizontalAlignment(.center)
                // Reporting is a modifier on ANY view - one handler per
                // space. Nothing is measured unless something asks: a view
                // without a handler is not even subscribed.
                .onFrameChanged { slot = $0 }
                .onFrameChanged(in: .global) { window = $0 }
                .onFrameChanged(in: .safeArea) { safe = $0 }
            }
            .padding(16)
            .background(Palette.selected)

            Slider($width)
                .minimum(140)
                .maximum(340)

            // Where the panel sits, in three spaces: inside the tinted box
            // above, inside the window, and inside the safe area.
            Text("in its parent · \\(Int(slot.x)), \\(Int(slot.y))")
            Text("in the window · \\(Int(window.x)), \\(Int(window.y))")
            Text("in the safe area · \\(Int(safe.x)), \\(Int(safe.y))")

            Button("Animate the width").onClicked {
                // Nothing is described: the host carries the width and the
                // slider's thumb off the same state, and the frame reports
                // say where the panel actually got to.
                try await $width.journey.move(to: $width.journey.value < 240 ? 340 : 140)
            }
        }
        """

    var body: some View {
        VStack {
            // `slot`, `window` and `safe` are read in these braces - the three
            // lines below print all of them - so every frame report builds
            // this closure, which is the whole cost of watching a frame.
            DebugInfoLabel()

            // THE PARENT, DRAWN in a gentle tint, because `slot` below is
            // measured against THIS box and the numbers say nothing until
            // there is something on the screen for them to be relative to.
            // It fills the page's width, so widening the panel walks its x
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
                        .fontAttributes(.bold)
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
            }
            .spacing(8)
            .padding(16)
            .background(Palette.selected)

            Slider($width)
                .accessibilityIdentifier("frameReader.width")
                .accessibilityLabel("Width")
                .minimum(140)
                .maximum(340)

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
                .padding(horizontal: 20, vertical: 10)
                .horizontalAlignment(.center)
                .onClicked {
                    // Nothing is described: the host carries the width and the
                    // slider's thumb off the same state, and the frame reports
                    // say where the panel actually got to.
                    try await $width.journey.move(to: $width.journey.value < 240 ? 340 : 140)
                }
        }
        .spacing(12)
    }

    var notes: (any View)? {
        VStack {
            Text("The tinted box is the parent, drawn because the first reading is measured "
                + "against it: `in its parent` is where the panel sits inside that box. "
                + "Widening the panel walks its x in towards the middle, while the window "
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
