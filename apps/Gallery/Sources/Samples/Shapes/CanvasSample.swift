import StateUI

/// A canvas drawn from state, and one drawn from a finger.
struct CanvasSample: SampleContent {
    static let id = "canvas"
    static let title = "Canvas"
    static let summary = "A canvas: the drawing instructions travel, and the host draws them."

    // A drag is a gesture, and a scroller would claim it before the canvas
    // heard about it - see SampleContent.scrolls.
    static let scrolls = false

    var examples: [Example] {
        [Example(FollowsState()), Example(FollowsAFinger())]
    }
}

/// A drawing described from state, redrawn because the state changed and for
/// no other reason.
private struct FollowsState: ExampleContent {
    @State private var bars = [0.4, 0.75, 0.3, 0.95, 0.6]

    static let code = """
        struct FollowsState: ContentView {
            @State private var bars = [0.4, 0.75, 0.3, 0.95, 0.6]

            var content: any View {
                VStack {
                    // The bars are read by the drawing below, so changing
                    // one builds this closure - which is what redraws it.
                    DebugInfoLabel()

                    Canvas {
                        for (index, value) in bars.enumerated() {
                            let height = value * 90
                            let x = Double(index) * 44

                            Draw.fillColor(Palette.accent)
                            Draw.fillRoundedRectangle(
                                x: x, y: 100 - height, width: 32, height: height,
                                cornerRadius: 4)

                            Draw.textColor(Palette.text)
                            Draw.fontSize(11)
                            Draw.drawText(
                                "\\(Int(value * 100))", x: x, y: 104, width: 32, height: 14,
                                horizontalAlignment: .center)
                        }
                    }
                    .height(120)

                    Button("Different numbers")
                        .onClicked { bars = bars.map { _ in Double.random(in: 0.15...1) } }
                }
            }
        }
        """

    var content: any View {
        VStack {
            DebugInfoLabel()

            Canvas {
                for (index, value) in bars.enumerated() {
                    let height = value * 90
                    let x = Double(index) * 44

                    Draw.fillColor(Palette.accent)
                    Draw.fillRoundedRectangle(
                        x: x, y: 100 - height, width: 32, height: height, cornerRadius: 4)

                    Draw.textColor(Palette.text)
                    Draw.fontSize(11)
                    Draw.drawText(
                        "\(Int(value * 100))", x: x, y: 104, width: 32, height: 14,
                        horizontalAlignment: .center)
                }
            }
            .height(120)

            Button("Different numbers")
                .fontSize(13)
                .padding(16, 6)
                .horizontalAlignment(.center)
                .onClicked { bars = bars.map { _ in Double.random(in: 0.15...1) } }
        }
        .spacing(12)
    }

    var notes: Element? {
        Label("The drawing is a list of instructions described in Swift. They travel to "
            + "the host, which draws them on the platform's canvas. The bars are read "
            + "inside the drawing, so new numbers draw it again.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}

/// The same canvas, drawn from what a finger is doing to it.
private struct FollowsAFinger: ExampleContent {
    @State private var trail: [Point] = []

    static let code = """
        struct FollowsAFinger: ContentView {
            @State private var trail: [Point] = []

            // Where a finger went, drawn where it went: the canvas reports in
            // its own coordinates, which is what the instructions use.
            var content: any View {
                VStack {
                    // The trail is read by the drawing, so every report the
                    // finger makes builds this closure and draws again.
                    DebugInfoLabel()

                    Canvas {
                        Draw.strokeColor(Palette.outline)
                        Draw.strokeWidth(1)
                        Draw.drawRoundedRectangle(
                            x: 1, y: 1, width: 300, height: 118, cornerRadius: 8)

                        Draw.fillColor(Palette.accent)
                        for point in trail {
                            Draw.fillEllipse(x: point.x - 4, y: point.y - 4, width: 8, height: 8)
                        }
                    }
                    .height(120)
                    .onPressed { trail = [$0] }
                    .onDragged { trail = Array((trail + [$0]).suffix(120)) }
                    .onReleased { _ in }

                    Button("Clear")
                        .isEnabled(!trail.isEmpty)
                        .onClicked { trail = [] }
                }
            }
        }
        """

    var content: any View {
        VStack {
            DebugInfoLabel()

            Canvas {
                Draw.strokeColor(Palette.outline)
                Draw.strokeWidth(1)
                Draw.drawRoundedRectangle(x: 1, y: 1, width: 300, height: 118, cornerRadius: 8)

                Draw.fillColor(Palette.accent)
                for point in trail {
                    Draw.fillEllipse(x: point.x - 4, y: point.y - 4, width: 8, height: 8)
                }
            }
            .height(120)
            .onPressed { trail = [$0] }
            .onDragged { trail = Array((trail + [$0]).suffix(120)) }
            .onReleased { _ in }

            Button("Clear")
                .fontSize(13)
                .padding(16, 6)
                .horizontalAlignment(.center)
                .isEnabled(!trail.isEmpty)
                .onClicked { trail = [] }
        }
        .spacing(12)
    }

    var notes: Element? {
        Label("Every point the finger reports is a write: the trail changes, the "
            + "drawing is described again, and the new instructions travel.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
