import StateUI

/// MAUI: VisualElement.InputTransparent and Layout.CascadeInputTransparent.
struct TouchThroughSample: SampleContent {
    static let id = "touchThrough"
    static let title = "Touch through"
    static let summary = "A view that is not touched at all, and whether that reaches its children."

    /// A gesture sample: the page holds the example still and scrolls the code.
    static let scrolls = false

    @State private var below = 0
    @State private var child = 0
    @State private var cascades = false

    static let code = """
        @State private var below = 0
        @State private var child = 0
        @State private var cascades = false

        Grid {
            // Both counts are read here, so a tap on either builds this closure.
            DebugInfoLabel()

            // Underneath, and still reachable.
            BoxView(Palette.accent)
                .heightRequest(120)
                .onTapped { below += 1 }

            // On top, and touched THROUGH - so a tap on the padding around
            // the label reaches the box below instead. False on the cascade
            // is what keeps the label itself touchable.
            VStack {
                // The child wears its own colour and its own padding, so what
                // is the child and what is the transparent view around it can
                // be told apart by eye - and aimed at separately.
                Label("tap the child")
                    .textColor(Palette.onBrand)
                    .backgroundColor(Palette.brand)
                    .padding(14, 8)
                    .horizontalOptions(.center)
                    .verticalOptions(.center)
                    .onTapped { child += 1 }
            }
            .padding(16)
            .inputTransparent(true)
            .cascadeInputTransparent(cascades)
        }
        """

    var content: Element {
        VStack {
            DebugInfoLabel()

            Grid {
                BoxView(Palette.accent)
                    .heightRequest(120)
                    .onTapped { below += 1 }

                VStack {
                    // The child wears its own colour and its own padding, so
                    // what is the child and what is the transparent view around
                    // it can be told apart by eye - and aimed at separately.
                    Label("tap the child")
                        .textColor(Palette.onBrand)
                        .backgroundColor(Palette.brand)
                        .padding(24, 12)
                        .horizontalOptions(.center)
                        .verticalOptions(.center)
                        .onTapped { child += 1 }
                }
                .padding(16)
                .inputTransparent(true)
                .cascadeInputTransparent(cascades)
            }

            Label("below \(below)   child \(child)")
                .fontSize(13)
                .horizontalOptions(.center)

            HStack {
                // The whole of the difference: with the cascade ON the label
                // stops counting too, and every tap reaches the box below.
                SwitchRow("Touch through", $cascades)

                Button("Reset")
                    .onClicked { below = 0; child = 0 }
            }
            .spacing(7)
            .horizontalOptions(.center)
        }
        .spacing(12)
    }

    var notes: Element? {
        VStack {
            Label("`inputTransparent` is not the same as being disabled. A DISABLED view "
                + "still takes the touch and does nothing with it; a transparent one is "
                + "not hit at all, so whatever is behind it hears the tap instead.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("`cascadeInputTransparent` says whether a layout's transparency reaches "
                + "its children. True - MAUI's default - lets everything through, the "
                + "children included. False keeps the children touchable while "
                + "the layout around them stops taking taps. The switch flips it.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Both halves answer the same way on all five platforms - a tap in the "
                + "transparent area reaches the box below, and the cascade decides whether "
                + "the child hears one.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
