import StateUI

/// What the library says when it is handed something it cannot use, routed to the page while it shows.
struct ComplaintsSample: SampleContent, ExampleContent {
    // listing: ComplaintsSample
    /// What the library said while the page showed, oldest first.
    @State private var heard: [String] = []

    /// A list of two, for a write past its end.
    @State private var pair = [1, 2]

    /// How many presses landed.
    @State private var presses = 0
    // listing: end

    static let id = "complaints"
    static let title = "Complaints"
    static let summary = "What the library says when it is handed something it cannot use - routed here while the page shows."

    // listing: ComplaintsSample
    var body: some View {
        VStack {
            Button("Write past the end of a list")
                .horizontalAlignment(.center)
                .onClicked {
                    // A binding to the third element of a list of two: the write is dropped.
                    let third = $pair[2]
                    third.wrappedValue = 3
                }

            // The second press supersedes the first, whose write is refused.
            Button("Press twice, quickly")
                .horizontalAlignment(.center)
                .onClicked(gate: .cancelPrevious) {
                    try? await Task.sleep(for: .seconds(1))
                    presses += 1
                }

            Text("\(presses) press(es) landed")
                .horizontalAlignment(.center)

            ForEach(Array(heard.enumerated()), id: \.offset) { item in
                Text(item.element)
                    .fontSize(12)
            }
        }
        .spacing(10)
        .onCreated {
            // Each complaint comes on the thread that complained, and is posted here.
            let heard = $heard
            Complaints.route { words in heard.post { $0 + [words] } }
        }
        .onDestroying { Complaints.route(to: nil) }
    }
    // listing: end

    var notes: (any View)? {
        Text("Each is said once a process; the Inspector's Complaints list them all.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
