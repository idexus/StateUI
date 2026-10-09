import StateUI

/// A colour, a size, a padding and a font size, each read off a state the host
/// moves on its own frames.
struct AnimatedPropertySample: SampleContent, ExampleContent {
    // listing: AnimatedPropertySample
    @State private var wide = false

    @State private var panelColor = AppColors.lineDark
    @State private var panelHeight = 90.0
    @State private var panelPadding = Insets(16)
    @State private var captionColor = AppColors.ink
    @State private var captionSize = 17.0
    // listing: end

    static let id = "animatedProperty"
    static let title = "Animated properties"
    static let summary = "A colour, a size and a padding carried to a new value by the host."

    // listing: AnimatedPropertySample
    var body: some View {
        VStack {
            // Every property below is driven, and `wide` is read by the
            // handler alone - so this stands at one build while five of them
            // travel at once.
            DebugInfoLabel()

            ZStack {
                Grid {
                    Text("A property, carried")
                        .fontSize($captionSize)
                        .textColor($captionColor)
                        .horizontalAlignment(.center)
                        .verticalAlignment(.center)
                }
                .background(AppColors.violetLight)
            }
            .style(.card)
            .background($panelColor)
            .padding($panelPadding)
            .height($panelHeight)
            .stroke(.transparent)
            .shape(.roundedRectangle(12))

            HStack {
                button("Colour") {
                    try await $panelColor.journey.move(to: AppColors.swiftOrangeDeep, .eased(500)).arrived()

                    // The caption sits on the brand field inside the panel
                    // rather than on the panel itself, so what it goes to is
                    // the colour that reads on the brand.
                    try await $captionColor.journey.move(to: AppColors.white, .eased(500)).arrived()
                }

                button("Size") {
                    wide.toggle()
                    try await $panelHeight.journey.move(to: wide ? 160 : 90,
                                                     .eased(400, .cubicInOut)).arrived()
                }

                button("Padding") {
                    try await $panelPadding.journey.move(to: Insets(48), .eased(400)).arrived()
                    try await $panelPadding.journey.move(to: Insets(16), .eased(400)).arrived()
                }
            }
            .spacing(8)
            .horizontalAlignment(.center)

            HStack {
                button("Text size") {
                    try await $captionSize.journey.move(to: 28, .eased(400, .cubicOut)).arrived()
                    try await $captionSize.journey.move(to: 17, .eased(400, .cubicIn)).arrived()
                }

                button("Back") {
                    // EVERYTHING THE OTHER BUTTONS LEAVE CHANGED - the height
                    // and the two colours. The padding and the text size send
                    // themselves back, so there is nothing here for them; and
                    // `wide` is put right with the height, or the next press
                    // of Size would ask for the value it already has.
                    wide = false

                    try await $panelHeight.journey.move(to: 90, .eased(400, .cubicInOut)).arrived()
                    try await $panelColor.journey.move(to: AppColors.lineDark, .eased(400)).arrived()
                    try await $captionColor.journey.move(to: AppColors.ink, .eased(400)).arrived()
                }
            }
            .spacing(8)
            .horizontalAlignment(.center)
        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("Each button moves a bound property on host frames. The build "
                + "counter stays still while colour, size, padding and text move.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Size moves the panel's height between 90 and 160. Back restores "
                + "the values that remain after their journeys.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }

    // listing: AnimatedPropertySample
    /// One of the buttons, all of which look the same.
    private func button(_ caption: String, _ act: @escaping EventHandler) -> Button {
        Button(caption)
            .onClicked(.cancelPrevious, act)
    }
    // listing: end
}
