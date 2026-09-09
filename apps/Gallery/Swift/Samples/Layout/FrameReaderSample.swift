import StateUI

/// Content built from the space it was given, and frames reported on request.
struct FrameReaderSample: SampleContent {
    @State private var slot = Rect(0, 0, 0, 0)
    @State private var window = Rect(0, 0, 0, 0)
    @State private var safe = Rect(0, 0, 0, 0)

    @State private var width = MotionChannel(220.0)

    static let id = "frameReader"
    static let title = "Measuring a frame"
    static let summary = "FrameReader builds content from its measured frame; .onFrameChanged reports any view's - in the parent, the window or the safe area."

    static let code = """
        @State private var width = MotionChannel(220.0)
        @State private var slot = Rect(0, 0, 0, 0)
        @State private var window = Rect(0, 0, 0, 0)
        @State private var safe = Rect(0, 0, 0, 0)

        VStack {
            // `slot`, `window` and `safe` are read in these braces - the line
            // below prints all three - so every frame report builds this
            // closure, which is the whole cost of watching a frame.
            DebugInfoLabel()

            // THE PARENT, DRAWN in a gentle tint, because `slot` below is
            // measured against THIS box and the numbers say nothing until
            // there is something on the screen for them to be relative to.
            // It fills the page's width, so widening the panel walks its x
            // in towards the middle.
            VStack {
                Label("the parent")

                // The reader's content is built FROM the measurement, which
                // is the reader's own @State. The three handlers write the
                // page's states instead, and the lines below print them - so
                // a settled frame builds the reader AND the page's braces.
                FrameReader { frame in
                    Label("\\(Int(frame.width)) × \\(Int(frame.height))")
                }
                // Driven: the host carries the width, and no render
                // describes it.
                .widthRequest($width)
                .heightRequest(120)
                .horizontalOptions(.center)
                // Reporting is a modifier on ANY view - one handler per
                // space. Nothing is measured unless something asks: a view
                // without a handler is not even subscribed.
                .onFrameChanged { slot = $0 }
                .onFrameChanged(in: .global) { window = $0 }
                .onFrameChanged(in: .safeArea) { safe = $0 }
            }
            .padding(16)
            .backgroundColor(Palette.selected)

            Slider($width)
                .minimum(140)
                .maximum(340)

            // Where the panel sits, in three spaces: inside the tinted box
            // above, inside the window, and inside the safe area.
            Label("in its parent · \\(Int(slot.x)), \\(Int(slot.y))")
            Label("in the window · \\(Int(window.x)), \\(Int(window.y))")
            Label("in the safe area · \\(Int(safe.x)), \\(Int(safe.y))")

            Button("Animate the width").onClicked {
                // Nothing is described: the host carries the width and the
                // slider's thumb off the same state, and the frame reports
                // say where the panel actually got to.
                try await $width.animateTo($width.value < 240 ? 340 : 140)
            }
        }
        """

    var content: Element {
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
                Label("the parent")
                    .fontSize(11)
                    .textColor(Palette.brand)

                // The reader's content is built FROM the measurement, which
                // is the reader's own @State. The three handlers write the
                // page's states instead, and the three lines below print
                // them - so a settled frame builds the reader AND the page.
                FrameReader { frame in
                    Label("\(Int(frame.width)) × \(Int(frame.height))")
                        .fontSize(22)
                        .fontAttributes(.bold)
                        .textColor(Palette.onAccent)
                        .horizontalOptions(.center)
                        .verticalOptions(.center)
                }
                // Driven: the host carries the width, and no render
                // describes it.
                .widthRequest($width)
                .heightRequest(120)
                .backgroundColor(Palette.accent)
                .horizontalOptions(.center)
                // Reporting is a modifier on ANY view - one handler per
                // space. Nothing is measured unless something asks: a view
                // without a handler is not even subscribed.
                .onFrameChanged { slot = $0 }
                .onFrameChanged(in: .global) { window = $0 }
                .onFrameChanged(in: .safeArea) { safe = $0 }
            }
            .spacing(8)
            .padding(16)
            .backgroundColor(Palette.selected)

            Slider($width)
                .automationId("frameReader.width")
                .semanticDescription("Width")
                .minimum(140)
                .maximum(340)

            // Where the panel sits, in three spaces. The first is against the
            // tinted box above, which is why that box is drawn at all.
            Label("in its parent · \(Int(slot.x)), \(Int(slot.y))")
                .fontSize(13)
                .textColor(Palette.brand)
                .horizontalTextAlignment(.center)

            Label("in the window · \(Int(window.x)), \(Int(window.y))")
                .fontSize(13)
                .horizontalTextAlignment(.center)

            Label("in the safe area · \(Int(safe.x)), \(Int(safe.y))")
                .fontSize(13)
                .horizontalTextAlignment(.center)

            Button("Animate the width")
                .padding(20, 10)
                .horizontalOptions(.center)
                .onClicked {
                    // Nothing is described: the host carries the width and the
                    // slider's thumb off the same state, and the frame reports
                    // say where the panel actually got to.
                    try await $width.animateTo($width.value < 240 ? 340 : 140)
                }
        }
        .spacing(12)
    }

    var notes: Element? {
        VStack {
            Label("THE TINTED BOX IS THE PARENT, and it is drawn because the first "
                + "reading is measured against it: `in its parent` is where the panel "
                + "sits INSIDE that box, so widening the panel walks its x in towards "
                + "the middle while the window and safe-area readings move by the "
                + "same amount from wherever the page happens to be. A frame is "
                + "always in some space, and this is which one.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The measurement costs nothing until it is asked for, and a report "
                + "comes when the frame settles somewhere new - dragging the slider "
                + "re-lays the panel out, and the walk reports every step of the way.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The panel's width and the slider's thumb are ONE driven state - "
                + ".widthRequest($width) and .value($width) - so dragging the thumb "
                + "resizes the panel without the page being described for it, and "
                + "the button sends that same state somewhere over 200ms.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("WHAT IS DESCRIBED AGAIN IS THE READER AND THIS PAGE. A driven "
                + "state describes nothing by itself, so the width costs no build "
                + "at all; what does is the MEASUREMENT. The reader builds its own "
                + "content from the frame it was given, and the three handlers "
                + "beside it write the page's own states, which the three lines "
                + "under the panel print - so the page is a reader of them too, "
                + "and the count at the top is its own builds. It moves for the "
                + "frame reports and for nothing else.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
