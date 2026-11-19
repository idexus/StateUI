import StateUI

/// A state an engine of the application's animates: the buttons say where the
/// dot goes, and a spring the engine works out frame by frame takes it there.
struct EngineAnimationSample: SampleContent, ExampleContent {
    // listing: EngineAnimationSample
    /// Where the dot is going; where it stands frame by frame is the engine's to say.
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
        .engine(animating: $offset) { cycle, motion in
            // A spring towards the destination, damped by the speed.
            let seconds = cycle.elapsedSeconds
            let pull = (motion.destination - motion.value) * 180 - motion.velocity * 12
            let velocity = motion.velocity + pull * seconds
            let value = motion.value + velocity * seconds

            // Near enough and slow enough, it is there: the engine says so.
            guard abs(motion.destination - value) > 0.5 || abs(velocity) > 1 else {
                motion.finish()
                return .wait
            }

            // This frame's place and speed; the host shows it as it comes.
            motion.update(value: value, velocity: velocity)
            return .again
        }
    }
    // listing: end

    var notes: (any View)? {
        Text("A button writes where the dot goes; the engine walks it there with a spring of its own, "
            + "and the host draws each frame it says. Where less motion is asked for the dot is "
            + "landed for it, and its arithmetic is not run.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
