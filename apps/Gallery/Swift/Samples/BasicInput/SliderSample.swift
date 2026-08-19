import StateUI

/// MAUI: Slider.
struct SliderSample: SampleContent {
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
                    .verticalOptions(.center)

                Switch($soundOn)
            }
        }
        """

    var content: Element {
        VStack {
            Label(soundOn ? "Volume: \(Int(volume))" : "Muted")
                .fontSize(17)
                .horizontalTextAlignment(.center)

            Slider($volume)
                .minimum(0)
                .maximum(100)
                .isEnabled(soundOn)
                .minimumTrackColor(Palette.accent)
                .onDragStarted { dragging = true }
                .onDragCompleted { dragging = false }

            Label(dragging ? "Dragging..." : "At rest")
                .fontSize(13)
                .horizontalTextAlignment(.center)

            HStack {
                Label("Sound")
                    .fontSize(14)
                    .verticalOptions(.center)

                Switch($soundOn)
                    .onColor(Palette.accent)
            }
            .spacing(12)
            .horizontalOptions(.center)

            Label("The drag's two ends are MAUI's own events - DragStarted as the thumb "
                + "is grabbed, DragCompleted as it is let go - and every step between "
                + "them is an onValueChanged. Work too heavy for every step belongs in "
                + "the completed end.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The value crosses the boundary as its own bits - nothing is "
                + "formatted or parsed on the way, so no locale can touch it.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
