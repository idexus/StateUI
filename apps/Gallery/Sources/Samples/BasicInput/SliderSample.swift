import StateUI

/// A native slider driven by one shared StateUI journey.
struct SliderSample: SampleContent, ExampleContent {
    // listing: SliderSample
    @State private var volume = 40.0
    @State private var soundOn = true
    @State private var dragging = false
    // listing: end

    static let id = "slider"
    static let title = "Slider"
    static let summary = "A value dragged along a track, and a number that crosses the boundary intact."

    // listing: SliderSample
    var body: some View {
        VStack {
            // The volume is READ here, so EVERY report the thumb makes builds
            // this closure - which is what a get on a dragged value costs.
            DebugInfoLabel()

            Text(soundOn ? "Volume: \(Int(volume))" : "Muted")
                .fontSize(17)
                .horizontalTextAlignment(.center)

            Slider($volume)
                .accessibilityIdentifier("slider.volume")
                .accessibilityLabel("Volume")
                .minimum(0)
                .maximum(100)
                .isEnabled(soundOn)
                .tint(Palette.accent)
                .onPressed { dragging = true }
                .onReleased { dragging = false }

            Text(dragging ? "Dragging..." : "At rest")
                .fontSize(13)
                .horizontalTextAlignment(.center)

            HStack {
                Text("Sound")
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
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("The drag's two ends are events of their own - `.onPressed` as the "
                + "thumb is grabbed, `.onReleased` as it is let go - and every step "
                + "between them is an `.onValueChanged`. Work too heavy for every step "
                + "belongs in the completed end.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("The value crosses the boundary as its own bits - nothing is formatted or "
                + "parsed on the way, so no locale can touch it.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
