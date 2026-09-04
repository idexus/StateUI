import StateUI

/// A colour, a size, a padding and a font size, each read off a state the host
/// moves on its own frames.
struct AnimatedPropertySample: SampleContent {
    @State private var wide = false

    @DrivenState private var panelColor = AnimatedValue(Palette.outline)
    @DrivenState private var panelHeight = AnimatedValue(90.0)
    @DrivenState private var panelPadding = AnimatedValue(Thickness(16))
    @DrivenState private var captionColor = AnimatedValue(Palette.text)
    @DrivenState private var captionSize = AnimatedValue(17.0)

    static let id = "animatedProperty"
    static let title = "Animated properties"
    static let summary = "A colour, a size and a padding carried to a new value by the host."

    static let code = """
        @State private var wide = false

        @DrivenState private var panelColor = AnimatedValue(Palette.outline)
        @DrivenState private var panelHeight = AnimatedValue(90.0)
        @DrivenState private var panelPadding = AnimatedValue(Thickness(16))
        @DrivenState private var captionColor = AnimatedValue(Palette.text)
        @DrivenState private var captionSize = AnimatedValue(17.0)

        VStack {
            Border {
                Label("A property, carried")
                    .fontSize($captionSize)
                    .textColor($captionColor)
            }
            .backgroundColor($panelColor)
            .padding($panelPadding)
            .heightRequest($panelHeight)

            Button("Colour").onClicked {
                try await $panelColor.animateTo(Palette.accent, .eased(500))
                try await $captionColor.animateTo(Palette.onBrand, .eased(500))
            }

            Button("Size").onClicked {
                wide.toggle()
                try await $panelHeight.animateTo(wide ? 160 : 90,
                                                 .eased(400, .cubicInOut))
            }

            Button("Padding").onClicked {
                try await $panelPadding.animateTo(Thickness(48), .eased(400))
                try await $panelPadding.animateTo(Thickness(16), .eased(400))
            }

            Button("Text size").onClicked {
                try await $captionSize.animateTo(28, .eased(400, .cubicOut))
                try await $captionSize.animateTo(17, .eased(400, .cubicIn))
            }

            Button("Back").onClicked {
                try await $panelColor.animateTo(Palette.outline, .eased(400))
                try await $captionColor.animateTo(Palette.text, .eased(400))
            }
        }
        """

    var example: Element {
        VStack {
            Border {
                Grid {
                    Label("A property, carried")
                        .fontSize($captionSize)
                        .textColor($captionColor)
                        .horizontalOptions(.center)
                        .verticalOptions(.center)
                }
                .backgroundColor(Palette.brand)
            }
            .backgroundColor($panelColor)
            .padding($panelPadding)
            .heightRequest($panelHeight)
            .stroke(.transparent)
            .strokeShape(.roundRectangle(12))

            HStack {
                button("Colour") {
                    try await $panelColor.animateTo(Palette.accent, .eased(500))

                    // The caption sits on the brand field inside the panel
                    // rather than on the panel itself, so what it goes to is
                    // the colour that reads on the brand.
                    try await $captionColor.animateTo(Palette.onBrand, .eased(500))
                }

                button("Size") {
                    wide.toggle()
                    try await $panelHeight.animateTo(wide ? 160 : 90,
                                                     .eased(400, .cubicInOut))
                }

                button("Padding") {
                    try await $panelPadding.animateTo(Thickness(48), .eased(400))
                    try await $panelPadding.animateTo(Thickness(16), .eased(400))
                }
            }
            .spacing(8)
            .horizontalOptions(.center)

            HStack {
                button("Text size") {
                    try await $captionSize.animateTo(28, .eased(400, .cubicOut))
                    try await $captionSize.animateTo(17, .eased(400, .cubicIn))
                }

                button("Back") {
                    try await $panelColor.animateTo(Palette.outline, .eased(400))
                    try await $captionColor.animateTo(Palette.text, .eased(400))
                }
            }
            .spacing(8)
            .horizontalOptions(.center)
        }
        .spacing(12)
    }

    var notes: Element? {
        VStack {
            Label("Five values, five DRIVEN states, and no render carries any of them. "
                + "Writing a property from a driven state - `.backgroundColor($panelColor)` "
                + "- registers it once and nothing mentions it again: "
                + "`$panelColor.animateTo(…)` sends the state and the host reads the "
                + "property off it every frame, while `panelColor.value = …` snaps it.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The state holds both readings at once. On the line after Size starts, "
                + "`panelHeight.setPoint` reads 160 while `panelHeight.value` is still "
                + "passing through 120 - where it is GOING and where it HAS GOT TO, in "
                + "one place. Nothing has to be put back, either: Padding goes out to 48 "
                + "and home to 16 because both are places the padding is meant to be.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("There is no handle here and no property name to spell. What can be "
                + "moved is what has a modifier taking a driven state - background "
                + "colour, padding, height, font size, text colour among them - and the "
                + "state's TYPE says what a target may be: `$panelColor` carries a "
                + "`Color` and takes a colour, `$captionSize` a number. A property with "
                + "no driven form has no such modifier, so it is the compiler that says "
                + "so and not at run time. A movement also starts from wherever the "
                + "value stands, which is why the height is 90 from the first frame.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }

    /// One of the buttons, all of which look the same.
    private func button(_ caption: String, _ act: @escaping EventHandler) -> Button {
        Button(caption)
            .fontSize(13)
            .padding(14, 6)
            .onClicked(act)
    }
}
