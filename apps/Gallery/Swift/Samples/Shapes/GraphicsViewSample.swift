import StateUI

/// MAUI: GraphicsView, and the ICanvas its drawable draws on.
struct GraphicsViewSample: SampleContent {
    @State private var bars = [0.4, 0.75, 0.3, 0.95, 0.6]
    @State private var trail: [Point] = []

    static let id = "graphicsView"
    static let title = "GraphicsView"
    static let summary = "A canvas: the instructions travel, and the host draws them."

    // A drag is a gesture, and a scroller would claim it before the canvas
    // heard about it - see SampleContent.scrolls.
    static let scrolls = false

    static let code = """
        @State private var bars = [0.4, 0.75, 0.3, 0.95, 0.6]
        @State private var trail: [Point] = []

        VStack {
            GraphicsView {
                for (index, value) in bars.enumerated() {
                    let height = value * 90
                    let x = Double(index) * 44

                    Draw.fillColor(Palette.accent)
                    Draw.fillRoundedRectangle(
                        x: x, y: 100 - height, width: 32, height: height, cornerRadius: 4)

                    Draw.fontColor(Palette.text)
                    Draw.fontSize(11)
                    Draw.drawString(
                        "\\(Int(value * 100))", x: x, y: 104, width: 32, height: 14,
                        horizontalAlignment: .center)
                }
            }
            .heightRequest(120)

            Button("Different numbers")
                .onClicked { bars = bars.map { _ in Double.random(in: 0.15...1) } }

            // Where a finger went, drawn where it went: the canvas reports in
            // its own coordinates, which is what the instructions use.
            GraphicsView {
                Draw.strokeColor(Palette.outline)
                Draw.strokeSize(1)
                Draw.drawRoundedRectangle(x: 1, y: 1, width: 300, height: 118, cornerRadius: 8)

                Draw.fillColor(Palette.accent)
                for point in trail {
                    Draw.fillEllipse(x: point.x - 4, y: point.y - 4, width: 8, height: 8)
                }
            }
            .heightRequest(120)
            .onStartInteraction { trail = [$0] }
            .onDragInteraction { trail = Array((trail + [$0]).suffix(120)) }
            .onEndInteraction { _ in }

            Button("Clear")
                .isEnabled(!trail.isEmpty)
                .onClicked { trail = [] }
        }
        """

    var content: Element {
        VStack {
            SectionTitle("A DRAWING THAT FOLLOWS STATE")

            GraphicsView {
                for (index, value) in bars.enumerated() {
                    let height = value * 90
                    let x = Double(index) * 44

                    Draw.fillColor(Palette.accent)
                    Draw.fillRoundedRectangle(
                        x: x, y: 100 - height, width: 32, height: height, cornerRadius: 4)

                    Draw.fontColor(Palette.text)
                    Draw.fontSize(11)
                    Draw.drawString(
                        "\(Int(value * 100))", x: x, y: 104, width: 32, height: 14,
                        horizontalAlignment: .center)
                }
            }
            .heightRequest(120)

            Button("Different numbers")
                .fontSize(13)
                .padding(16, 6)
                .horizontalOptions(.center)
                .onClicked { bars = bars.map { _ in Double.random(in: 0.15...1) } }

            Label("MAUI's GraphicsView takes an IDrawable - an object with a Draw method, "
                + "which is the one thing this boundary cannot carry. So the calls that "
                + "method would have made travel instead, and the host replays them.")
                .fontSize(12)
                .textColor(Palette.subtle)

            SectionTitle("AND ONE THAT FOLLOWS A FINGER")

            GraphicsView {
                Draw.strokeColor(Palette.outline)
                Draw.strokeSize(1)
                Draw.drawRoundedRectangle(x: 1, y: 1, width: 300, height: 118, cornerRadius: 8)

                Draw.fillColor(Palette.accent)
                for point in trail {
                    Draw.fillEllipse(x: point.x - 4, y: point.y - 4, width: 8, height: 8)
                }
            }
            .heightRequest(120)
            .onStartInteraction { trail = [$0] }
            .onDragInteraction { trail = Array((trail + [$0]).suffix(120)) }
            .onEndInteraction { _ in }

            Button("Clear")
                .fontSize(13)
                .padding(16, 6)
                .horizontalOptions(.center)
                .isEnabled(!trail.isEmpty)
                .onClicked { trail = [] }

            Label("Every point is a render: the state changes, the instructions are read "
                + "again, and the new drawing is what crosses. Nothing else was needed to "
                + "make a drawing follow the interface it belongs to.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
