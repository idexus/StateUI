import StateUI

/// Gradients along a line and out from a point, on a fill, a stroke and a background.
struct BrushSample: SampleContent, ExampleContent {
    // listing: BrushSample
    @State private var end = 0
    // listing: end

    static let id = "brush"
    static let title = "Brushes"
    static let summary = "Gradients: on a shape's fill, a layout's outline, and behind any view at all."

    // listing: BrushSample
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

    var body: some View {
        // Not a shape at all: `.background` takes a brush, so any view can
        // carry one.
        VStack {
            // The gradient's end is read here, so moving it builds this closure.
            DebugInfoLabel()

            SectionTitle("Along a line")

            Rectangle()
                .cornerRadius(12)
                .fill(.linearGradient(
                    Self.stops,
                    startPoint: Point(0, 0),
                    endPoint: Self.ends[end].point))
                .contentMode(.stretch)   // fills the room, proportions and all
                .height(80)

            Button("endPoint: \(Self.ends[end].name)")
                .fontSize(13)
                .padding(horizontal: 16, vertical: 6)
                .horizontalAlignment(.center)
                .onClicked { end = (end + 1) % Self.ends.count }

            SectionTitle("Out from a point")

            Ellipse()
                .fill(.radialGradient(
                    [GradientStop(.white, 0), GradientStop(.steelBlue, 1)],
                    center: Point(0.35, 0.3),
                    radius: 0.75))
                .width(96)
                .height(96)
                .horizontalAlignment(.center)

            SectionTitle("On a stroke and a background")

            ZStack {
                Text("A stroke is a brush too")
                    .fontSize(14)
                    .padding(horizontal: 16, vertical: 10)
            }
            .style("Card")
            .lineWidth(4)
            .shape(.roundedRectangle(10))
            .stroke(.linearGradient(Self.stops, startPoint: Point(0, 0), endPoint: Point(1, 0)))

            VStack {
                Text("A whole stack, behind a gradient")
                    .fontSize(14)
                    .textColor(Palette.onAccent)
                    .horizontalTextAlignment(.center)
            }
            .padding(16)
            .background(.linearGradient(Self.stops, startPoint: Point(0, 0), endPoint: Point(1, 1)))
        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("A gradient's points are fractions of the thing being painted, not device "
                + "units: `Point(0, 0)` is its top left corner and `Point(1, 1)` its bottom "
                + "right. So the axis follows the box's own corners rather than a fixed "
                + "angle - and on a bar this wide, corner to corner is only a few degrees "
                + "off straight across.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("`.background` takes one colour or a brush; it is one property, so a "
                + "view given both draws the one it was given last.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("A stop's colour may be written `Color(light:dark:)`, and it picks its half "
                + "as the view wearing the gradient is built - the first stop above is "
                + "the gallery's accent, which is a lighter orange in the dark.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
