import StateUI

/// A state an engine of the application's animates: the buttons say where the
/// dot goes, and a spring the engine works out frame by frame takes it there.
struct EngineAnimationSample: SampleContent, ExampleContent {
    // listing: EngineAnimationSample
    /// Where the dot is going - and, frame by frame, where the engine has it.
    @State(animatedBy: .engine) private var offset = 0.0
    // listing: end

    static let id = "engine-animation"
    static let title = "Engine animation"
    static let summary = "A state an engine animates: a spring worked out on the host's frames."

    // listing: EngineAnimationSample
    var body: some View {
        VStack {
            Ellipse()
                .fill(Palette.accent)
                .width(32)
                .height(32)
                .translationX($offset)
                .horizontalAlignment(.center)

            HStack {
                Button("Left").onClicked { offset = -120 }
                Button("Center").onClicked { offset = 0 }
                Button("Right").onClicked { offset = 120 }
            }
            .spacing(8)
            .horizontalAlignment(.center)
        }
        .spacing(16)
        .engine(tracking: $offset) { cycle in
            let journey = $offset.journey

            // With less motion the dot lands where it is sent.
            guard !cycle.reducesMotion else {
                journey.snap(to: journey.destination)
                return .wait
            }

            // A spring towards the destination, damped by the speed.
            let seconds = cycle.elapsedSeconds
            let pull = (journey.destination - journey.value) * 180 - journey.velocity * 12
            journey.velocity += pull * seconds
            journey.value += journey.velocity * seconds

            guard abs(journey.destination - journey.value) < 0.5, abs(journey.velocity) < 1 else { return .again }
            journey.snap(to: journey.destination)
            return .wait
        }
    }
    // listing: end

    var notes: (any View)? {
        Text("A button writes where the dot goes; the engine walks it there with a spring of its own, "
            + "and the host draws each value it writes.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
