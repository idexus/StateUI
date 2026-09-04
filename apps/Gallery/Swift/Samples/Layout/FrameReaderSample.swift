import StateUI

/// Content built from the space it was given, and frames reported on request.
struct FrameReaderSample: SampleContent {
    @State private var slot = Rect(0, 0, 0, 0)
    @State private var window = Rect(0, 0, 0, 0)
    @State private var safe = Rect(0, 0, 0, 0)

    @Animated private var width = 220.0

    static let id = "frameReader"
    static let title = "Measuring a frame"
    static let summary = "FrameReader builds content from its measured frame; .onFrameChanged reports any view's - in the parent, the window or the safe area."

    static let code = """
        @Animated private var width = 220.0
        @State private var slot = Rect(0, 0, 0, 0)
        @State private var window = Rect(0, 0, 0, 0)
        @State private var safe = Rect(0, 0, 0, 0)

        VStack {
            // The reader's content is built FROM the measurement, and the
            // measurement lives in the reader's own @State - so a settled
            // frame rebuilds this closure and nothing else on the page.
            FrameReader { frame in
                Label("\\(Int(frame.width)) × \\(Int(frame.height))")
            }
            // Driven: the host carries the width, and no render describes it.
            .widthRequest($width)
            .heightRequest(120)
            // Reporting is a modifier on ANY view - one handler per
            // space. Nothing is measured unless something asks: a view
            // without a handler is not even subscribed.
            .onFrameChanged { slot = $0 }
            .onFrameChanged(in: .global) { window = $0 }
            .onFrameChanged(in: .safeArea) { safe = $0 }

            Slider($width)
                .minimum(140)
                .maximum(340)

            Label("parent \\(Int(slot.x)), \\(Int(slot.y))"
                + " · window \\(Int(window.x)), \\(Int(window.y))"
                + " · safe area \\(Int(safe.x)), \\(Int(safe.y))")

            Button("Animate the width").onClicked {
                // Nothing is described: the host carries the width and the
                // slider's thumb off the same state, and the frame reports
                // say where the panel actually got to.
                try await $width.animateTo($width.value < 240 ? 340 : 140)
            }
        }
        """

    var example: Element {
        VStack {
            // The reader's content is built FROM the measurement, and the
            // measurement lives in the reader's own @State - so a settled
            // frame rebuilds this closure and nothing else on the page.
            FrameReader { frame in
                Label("\(Int(frame.width)) × \(Int(frame.height))")
                    .fontSize(22)
                    .fontAttributes(.bold)
                    .horizontalOptions(.center)
                    .verticalOptions(.center)
            }
            // Driven: the host carries the width, and no render describes it.
            .widthRequest($width)
            .heightRequest(120)
            .backgroundColor(Palette.selected)
            .horizontalOptions(.center)
            // Reporting is a modifier on ANY view - one handler per space.
            // Nothing is measured unless something asks: a view without a
            // handler is not even subscribed.
            .onFrameChanged { slot = $0 }
            .onFrameChanged(in: .global) { window = $0 }
            .onFrameChanged(in: .safeArea) { safe = $0 }

            Slider($width)
                .minimum(140)
                .maximum(340)

            Label("parent \(Int(slot.x)), \(Int(slot.y))")
                .fontSize(13)
                .horizontalTextAlignment(.center)

            Label(" · window \(Int(window.x)), \(Int(window.y))")
                .fontSize(13)
                .horizontalTextAlignment(.center)

            Label(" · safe area \(Int(safe.x)), \(Int(safe.y))")
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
            Label("The measurement costs nothing until it is asked for, and a report "
                + "comes when the frame settles somewhere new - dragging the slider "
                + "re-lays the panel out, and the walk reports every step of the way.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The panel's width and the slider's thumb are ONE driven state - "
                + ".widthRequest($width) and .value($width) - so dragging the thumb "
                + "resizes the panel with nothing described in between, and the "
                + "button sends the same state somewhere over 200ms. The frame "
                + "reports are what say where the panel got to.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
