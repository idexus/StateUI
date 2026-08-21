import StateUI

/// MAUI: VisualElement.Rotation, RotationX, RotationY, Scale and the anchor.
struct TransformSample: SampleContent {
    static let id = "transform"
    static let title = "Transforms"
    static let summary = "Turning, tipping and resizing a view after it has been laid out."

    static let code = """
        HStack {
            // Flat, in the plane of the screen.
            BoxView(Palette.accent)
                .rotation(20)

            // Tipped about the horizontal axis: the top goes away.
            BoxView(Palette.accent)
                .rotationX(55)

            // Turned about the vertical axis: one side goes away.
            BoxView(Palette.accent)
                .rotationY(55)

            // Drawing only - the room the layout gave it does not change.
            BoxView(Palette.accent)
                .scale(1.4)

            // The pivot moved to the top left corner.
            BoxView(Palette.accent)
                .rotation(20)
                .anchorX(0)
                .anchorY(0)
        }
        """

    var content: Element {
        HStack {
            piece(box().rotation(20), "rotation")
            piece(box().rotationX(55), "rotationX")
            piece(box().rotationY(55), "rotationY")
            piece(box().scale(1.4), "scale")
            piece(box().rotation(20).anchorX(0).anchorY(0), "anchor 0,0")
        }
        .spacing(18)
        .horizontalOptions(.center)
    }

    var notes: Element? {
        VStack {
            Label("A transform happens AFTER the layout: the view keeps the room it was "
                + "given, and only what is drawn moves. That is why a scaled view can "
                + "overlap its neighbour without pushing it aside.")

            Label("`rotationX` and `rotationY` tip the view out of the plane of the "
                + "screen, so a square becomes a trapezium; `rotation` turns it within "
                + "that plane and a square stays square.")

            Label("All three pivot about the ANCHOR, which is the middle until it is "
                + "moved: 0 is the left edge or the top, 1 the right edge or the bottom.")
        }
        .spacing(8)
    }

    /// The square every example transforms - sized here, because a transform
    /// is about what is DRAWN and the room each one gets has to be the same.
    private func box() -> BoxView {
        BoxView(Palette.accent)
            .widthRequest(44)
            .heightRequest(44)
    }

    /// One piece with its caption, so the row reads as five labelled examples
    /// rather than five boxes.
    private func piece(_ view: Element, _ caption: String) -> Element {
        VStack {
            view

            Label(caption)
                .fontSize(11)
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)
        }
        .spacing(10)
    }
}
