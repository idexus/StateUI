import StateUI

/// MAUI: AnimationExtensions.Animate, which is what the host walks a property
/// with when MAUI has no method of its own for it.
struct AnimatedPropertySample: SampleContent {
    @State private var wide = false

    @State private var panelColor = Palette.outline
    @State private var panelHeight = 90.0
    @State private var panelPadding = Thickness(16)
    @State private var captionColor = Palette.text
    @State private var captionSize = 17.0

    static let id = "animatedProperty"
    static let title = "Animated properties"
    static let summary = "A colour, a size and a padding walked to a new value."

    static let code = """
        @State private var wide = false

        @State private var panelColor = Palette.outline
        @State private var panelHeight = 90.0
        @State private var panelPadding = Thickness(16)
        @State private var captionColor = Palette.text
        @State private var captionSize = 17.0

        VStack {
            Border {
                Label("A property, walked")
                    .fontSize($captionSize)
                    .textColor($captionColor)
            }
            .backgroundColor($panelColor)
            .padding($panelPadding)
            .heightRequest($panelHeight)

            Button("Colour").onClicked {
                try await $panelColor.animateTo(Palette.accent, length: 500)
                try await $captionColor.animateTo(Palette.onAccent, length: 500)
            }

            Button("Size").onClicked {
                wide.toggle()
                try await $panelHeight.animateTo(wide ? 160 : 90,
                                                 length: 400, easing: .cubicInOut)
            }

            Button("Padding").onClicked {
                try await $panelPadding.animateTo(Thickness(48), length: 400)
                try await $panelPadding.animateTo(Thickness(16), length: 400)
            }

            Button("Text size").onClicked {
                try await $captionSize.animateTo(28, length: 400, easing: .cubicOut)
                try await $captionSize.animateTo(17, length: 400, easing: .cubicIn)
            }

            Button("Back").onClicked {
                try await $panelColor.animateTo(Palette.outline, length: 400)
                try await $captionColor.animateTo(Palette.text, length: 400)
            }
        }
        """

    var content: Element {
        VStack {
            Border {
                Grid {
                    Label("A property, walked")
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
                    try await $panelColor.animateTo(Palette.accent, length: 500)

                    // The caption sits on the brand field inside the panel
                    // rather than on the panel itself, so what it walks to is
                    // the colour that reads on the brand.
                    try await $captionColor.animateTo(Palette.onBrand, length: 500)
                }

                button("Size") {
                    wide.toggle()
                    try await $panelHeight.animateTo(wide ? 160 : 90,
                                                     length: 400, easing: .cubicInOut)
                }

                button("Padding") {
                    try await $panelPadding.animateTo(Thickness(48), length: 400)
                    try await $panelPadding.animateTo(Thickness(16), length: 400)
                }
            }
            .spacing(8)
            .horizontalOptions(.center)

            HStack {
                button("Text size") {
                    try await $captionSize.animateTo(28, length: 400, easing: .cubicOut)
                    try await $captionSize.animateTo(17, length: 400, easing: .cubicIn)
                }

                button("Back") {
                    try await $panelColor.animateTo(Palette.outline, length: 400)
                    try await $captionColor.animateTo(Palette.text, length: 400)
                }
            }
            .spacing(8)
            .horizontalOptions(.center)
        }
        .spacing(12)
    }

    var notes: Element? {
        VStack {
            Label("Five values, five pieces of @State, and the tree reads every one of "
                + "them. Writing a property FROM its state - `.backgroundColor($panelColor)` "
                + "- both describes it and ARMS it, which is all it takes: "
                + "`$panelColor.animateTo(…)` then walks the control there, while "
                + "assigning `panelColor` snaps it. One property, two spellings, and the "
                + "spelling is the whole difference.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The state is given the target AT ONCE. On the line after Size starts "
                + "its flight, `panelHeight` reads 160 while the border is still passing "
                + "through 120 - the tree says where the value is GOING and the walk is "
                + "the control's, so a render in the middle of one has nothing new to "
                + "say. Nothing has to be put back, either: Padding goes out to 48 and "
                + "home to 16 because both are places the padding is meant to be.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("There is no handle here and no property name to spell. What can be "
                + "flown is what has a modifier taking a binding - background colour, "
                + "padding, height, font size, text colour among them - and the state's "
                + "TYPE says what a target may be: `$panelColor` is a `Binding<Color>` "
                + "and takes a colour, `$captionSize` a number. A property with no armed "
                + "form has no such modifier, so it is the compiler that says so and not "
                + "the host at run time. A flight also starts from whatever the state "
                + "already holds, which is why the height is 90 from the first render: "
                + "there is no way left to walk a property the tree never mentioned.")
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
