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

            // The same value with a picture for a thumb, asked for by the
            // name the build gives the file - and one per theme, since the
            // artwork has to read on both.
            Slider($volume)
                .minimum(0)
                .maximum(100)
                .thumbImageSource(
                    ImageSource(light: "nav_gestures.png", dark: "nav_gestures_dark.png"))
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

            SectionTitle("A PICTURE FOR THE THUMB")

            Slider($volume)
                .minimum(0)
                .maximum(100)
                .minimumTrackColor(Palette.accent)
                .thumbImageSource(
                    ImageSource(light: "nav_gestures.png", dark: "nav_gestures_dark.png"))

            Label("The same value, dragged by a hand: `thumbImageSource` REPLACES the "
                + "platform's thumb rather than tinting it, so a `thumbColor` written "
                + "beside it paints nothing. Both sliders hold `volume`, so either one "
                + "moves the other.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The name is the file in Resources/Images as the build leaves it - "
                + "nav_gestures.svg is asked for as nav_gestures.png - and there is no "
                + "size beside it, so how big the thumb draws is how big the artwork is. "
                + "A picture that must read on both themes is two files, exactly as it "
                + "is for an Image.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
