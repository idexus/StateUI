import StateUI

/// A native slider driven by one shared StateUI journey.
struct SliderSample: SampleContent, ExampleContent {
    @State private var volume = 40.0
    @State private var soundOn = true
    @State private var dragging = false

    static let id = "slider"
    static let title = "Slider"
    static let summary = "A value dragged along a track, and a number that crosses the boundary intact."

    static let code = """
        @State private var volume = 40.0
        @State private var soundOn = true
        @State private var dragging = false

        VStack {
            // The volume is READ here, so EVERY report the thumb makes builds
            // this closure - which is what a get on a dragged value costs.
            DebugInfoLabel()

            Label(soundOn ? "Volume: \\(Int(volume))" : "Muted")

            Slider($volume)
                .minimum(0)
                .maximum(100)
                .isEnabled(soundOn)
                .onDragStarted { dragging = true }
                .onDragCompleted { dragging = false }

            Label(dragging ? "Dragging..." : "At rest")

            HStack {
                Label("Sound")
                    .verticalAlignment(.center)

                Switch($soundOn)
            }
        }
        """

    var content: any View {
        VStack {
            DebugInfoLabel()

            Label(soundOn ? "Volume: \(Int(volume))" : "Muted")
                .fontSize(17)
                .horizontalTextAlignment(.center)

            Slider($volume)
                .accessibilityIdentifier("slider.volume")
                .accessibilityLabel("Volume")
                .minimum(0)
                .maximum(100)
                .isEnabled(soundOn)
                .tint(Palette.accent)
                .onDragStarted { dragging = true }
                .onDragCompleted { dragging = false }

            Label(dragging ? "Dragging..." : "At rest")
                .fontSize(13)
                .horizontalTextAlignment(.center)

            HStack {
                Label("Sound")
                    .fontSize(14)
                    .verticalAlignment(.center)

                Switch($soundOn)
                    .accessibilityIdentifier("slider.sound")
                    .accessibilityLabel("Sound on")
                    .tint(Palette.accent)
            }
            .spacing(12)
            .horizontalAlignment(.center)
        }
        .spacing(12)
    }

    var notes: Element? {
        VStack {
            Label("The drag's two ends are events of their own - `.onDragStarted` as the "
                + "thumb is grabbed, `.onDragCompleted` as it is let go - and every step "
                + "between them is an `.onValueChanged`. Work too heavy for every step "
                + "belongs in the completed end.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The value crosses the boundary as its own bits - nothing is formatted or "
                + "parsed on the way, so no locale can touch it.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
