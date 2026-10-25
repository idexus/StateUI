import StateUI

/// The platform's type ramp, from display to caption, the four weights, and digits of one width.
struct TextStyleSample: SampleContent, ExampleContent {
    static let id = "text-style"
    static let title = "Text style"
    static let summary = "The platform's own sizes for a title, a body and a caption, four weights, and digits of one width."

    // listing: TextStyleSample
    /// The step a line stands at, moved by the buttons and handed to the line as a state.
    @State private var style = TextStyle.title

    /// The seconds a countdown has left, and whether its digits are all as wide.
    @State private var seconds = 20
    @State private var monospaced = true

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

            // With digits of their own width, the words after the number move as it counts.
            HStack {
                Text("\(seconds) s left").fontAttributes(monospaced ? .monospacedDigits : .none)
                Button("Count down").onClicked(.cancelPrevious) {
                    seconds = 20
                    while seconds > 0 {
                        try await Task.sleep(for: .milliseconds(300))
                        seconds -= 1
                    }
                }
            }
            .spacing(12)

            Switch($monospaced).text("Digits of one width")
        }
        .spacing(8)
    }
    // listing: end

    var notes: (any View)? {
        Text("Press Larger or Smaller to move a line through the ramp; count down with and without digits of one width.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
