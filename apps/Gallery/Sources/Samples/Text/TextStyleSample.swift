import StateUI

/// The platform's type ramp, from display to caption, and the four weights.
struct TextStyleSample: SampleContent, ExampleContent {
    static let id = "text-style"
    static let title = "Text style"
    static let summary = "The platform's own sizes for a title, a body and a caption, and four weights."

    // listing: TextStyleSample
    /// The step a line stands at, moved by the buttons and handed to the line as a state.
    @State private var style = TextStyle.title

    var body: some View {
        VStack {
            Text("Display").textStyle(.display)
            Text("Title").textStyle(.title)
            Text("Subtitle").textStyle(.subtitle)
            Text("Headline").textStyle(.headline)
            Text("Body").textStyle(.body)
            Text("Caption").textStyle(.caption)

            HStack {
                Text("Regular").fontWeight(.regular)
                Text("Medium").fontWeight(.medium)
                Text("Semibold").fontWeight(.semibold)
                Text("Bold").fontWeight(.bold)
            }
            .spacing(16)

            Text("A title, at a weight of its own").textStyle(.title).fontWeight(.regular)

            Text("Stepped through the ramp").textStyle($style)

            HStack {
                Button("Larger").onClicked { style = TextStyle(rawValue: style.rawValue - 1) ?? .display }
                Button("Smaller").onClicked { style = TextStyle(rawValue: style.rawValue + 1) ?? .caption }
            }
            .spacing(8)
        }
        .spacing(8)
    }
    // listing: end

    var notes: (any View)? {
        Text("Press Larger or Smaller to move the last line through the ramp.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
