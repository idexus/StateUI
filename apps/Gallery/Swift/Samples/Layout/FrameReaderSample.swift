import StateUI

/// Content built from the space it was given, and frames reported on request.
struct FrameReaderSample: SampleContent {
    @State private var width = 220.0
    @State private var slot = Rect(0, 0, 0, 0)
    @State private var window = Rect(0, 0, 0, 0)
    @State private var safe = Rect(0, 0, 0, 0)

    static let id = "frameReader"
    static let title = "Measuring a frame"
    static let summary = "FrameReader builds content from its measured frame; .onFrameChanged reports any view's - in the parent, the window or the safe area."

    static let code = """
        @State private var width = 220.0
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
            // Armed: the width is the STATE's, dragged or flown.
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
                // There is nothing to write back: `width` holds where the
                // panel is going from the moment the walk starts, and the
                // frame reports say where it has got to.
                try await $width.animateTo(width < 240 ? 340 : 140)
            }
        }
        """

    var content: Element {
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
            // Armed: the width is the STATE's, dragged or flown.
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
                    // There is nothing to write back: `width` holds where the
                    // panel is going from the moment the walk starts, and the
                    // frame reports say where it has got to.
                    try await $width.animateTo(width < 240 ? 340 : 140)
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

            Label("The width is ARMED - .widthRequest($width) rather than "
                + ".widthRequest(width) - so the animation is that state moving: "
                + "assigning width snaps the panel to it, flying it walks there. "
                + "The state is given the target as the walk begins, which is why the "
                + "slider arrives before the panel does, and why the frame reports are "
                + "the thing here that says where the panel actually is.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
