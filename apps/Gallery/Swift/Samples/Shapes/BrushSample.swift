import StateUI

/// MAUI: Brush, SolidColorBrush, LinearGradientBrush, RadialGradientBrush.
struct BrushSample: SampleContent {
    @State private var end = 0

    static let id = "brush"
    static let title = "Brushes"
    static let summary = "Gradients: on a shape's fill, a border's stroke, and behind any view at all."

    static let code = """
        @State private var end = 0

        /// The two stops every gradient here runs between.
        private static let stops = [
            GradientStop(Palette.accent, 0),
            GradientStop(.steelBlue, 1),
        ]

        /// Across, down, and corner to corner - the three the button cycles.
        private static let ends: [(point: Point, name: String)] = [
            (Point(1, 0), "Point(1, 0)"),
            (Point(0, 1), "Point(0, 1)"),
            (Point(1, 1), "Point(1, 1)"),
        ]

        VStack {
            RoundRectangle()
                .cornerRadius(12)
                .fill(.linearGradient(
                    Self.stops,
                    startPoint: Point(0, 0),
                    endPoint: Self.ends[end].point))
                .heightRequest(80)

            Button("endPoint: \\(Self.ends[end].name)")
                .onClicked { end = (end + 1) % Self.ends.count }

            Ellipse()
                .fill(.radialGradient(
                    [GradientStop(.white, 0), GradientStop(.steelBlue, 1)],
                    center: Point(0.35, 0.3),
                    radius: 0.75))
                .widthRequest(96)
                .heightRequest(96)

            Border {
                Label("A stroke is a brush too")
                    .padding(16, 10)
            }
            .strokeThickness(4)
            .strokeShape(.roundRectangle(10))
            .stroke(.linearGradient(Self.stops, startPoint: Point(0, 0), endPoint: Point(1, 0)))

            // Not a shape at all: VisualElement.Background takes a brush, so any
            // view can carry one.
            VStack {
                Label("A whole stack, behind a gradient")
                    .textColor(Palette.onAccent)
            }
            .background(.linearGradient(Self.stops, startPoint: Point(0, 0), endPoint: Point(1, 1)))
        }
        """

    /// The two stops every gradient here runs between.
    private static let stops = [
        GradientStop(Palette.accent, 0),
        GradientStop(.steelBlue, 1),
    ]

    /// Across, down, and corner to corner - the three the button cycles.
    private static let ends: [(point: Point, name: String)] = [
        (Point(1, 0), "Point(1, 0)"),
        (Point(0, 1), "Point(0, 1)"),
        (Point(1, 1), "Point(1, 1)"),
    ]

    var example: Element {
        VStack {
            SectionTitle("ALONG A LINE")

            RoundRectangle()
                .cornerRadius(12)
                .fill(.linearGradient(
                    Self.stops,
                    startPoint: Point(0, 0),
                    endPoint: Self.ends[end].point))
                .heightRequest(80)

            Button("endPoint: \(Self.ends[end].name)")
                .fontSize(13)
                .padding(16, 6)
                .horizontalOptions(.center)
                .onClicked { end = (end + 1) % Self.ends.count }

            Label("The points are fractions of the thing being painted, not device units: "
                + "Point(0, 0) is its top left corner and Point(1, 1) its bottom right. "
                + "So the axis follows the box's own corners rather than a fixed angle - "
                + "and on a bar this wide, corner to corner is only a few degrees off "
                + "the one straight across.")
                .fontSize(12)
                .textColor(Palette.subtle)

            SectionTitle("OUT FROM A POINT")

            Ellipse()
                .fill(.radialGradient(
                    [GradientStop(.white, 0), GradientStop(.steelBlue, 1)],
                    center: Point(0.35, 0.3),
                    radius: 0.75))
                .widthRequest(96)
                .heightRequest(96)
                .horizontalOptions(.center)

            SectionTitle("WHEREVER MAUI TAKES A BRUSH")

            Border {
                Label("A stroke is a brush too")
                    .fontSize(14)
                    .padding(16, 10)
            }
            .strokeThickness(4)
            .strokeShape(.roundRectangle(10))
            .stroke(.linearGradient(Self.stops, startPoint: Point(0, 0), endPoint: Point(1, 0)))

            VStack {
                Label("A whole stack, behind a gradient")
                    .fontSize(14)
                    .textColor(Palette.onAccent)
                    .horizontalTextAlignment(.center)
            }
            .padding(16)
            .background(.linearGradient(Self.stops, startPoint: Point(0, 0), endPoint: Point(1, 1)))

        }
        .spacing(12)
    }

    var notes: Element? {
        VStack {
            Label("`.backgroundColor` is one colour and `.background` is a brush - both are "
                + "MAUI's, and a view given both draws the brush.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("A stop's colour may be written Color(light:dark:), and it picks its half "
                + "as the gradient is written - the first stop above is the gallery's "
                + "accent, which is a different purple in the dark.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("This is the one value MAUI has a string syntax for that does NOT travel "
                + "in it: its CSS parser drops a stop written without a percentage and "
                + "reads `red` as no colour at all. So a brush travels as what it is - "
                + "the kind, its geometry, and a colour per stop.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
