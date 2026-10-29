import StateUI

/// A conversation whose field and Send button stand at the foot of its page: the bar grows with the field's lines and
/// stands on the keyboard, and at the conversation's end the last message stays in sight as it grows.
struct BottomBarSample: SampleContent, ExampleContent {
    // listing: BottomBarSample
    @State private var presented = false
    @State private var path: [Int] = []
    @State private var messages = (1...24).map { "Message \($0)" }
    @State private var draft = ""
    @State private var edge = ScrollEdge.automatic
    static let edges: [ScrollEdge] = [.automatic, .hard, .none]

    /// What the window is made of, which the field's blur is tinted with as the bars' are.
    @Environment(\.window) private var window
    // listing: end

    static let id = "bottomBar"
    static let title = "Bottom bar"
    static let summary = "A view at the foot of a page: the page stands clear of it, its rows scrolling under it."

    // listing: BottomBarSample
    var body: some View {
        VStack {
            // How the rows show at the bar's edge as they pass under it.
            Picker(Self.edges, selection: $edge) { "\($0)".titled }
                .accessibilityLabel("Edge")
                .presentation(.segmented)

            Button("Open the conversation")
                .onClicked { presented = true }
                .sheet(isPresented: $presented) { conversation }
        }
        .spacing(12)
    }

    private var conversation: some View {
        NavigationStack($path) {
            Grid {
                ScrollView {
                    VStack {
                        ForEach(Array(messages.indices), id: \.self) { index in
                            Text(messages[index])
                        }
                    }
                    .spacing(14)
                    .padding(20)
                }
            }
            .ignoresSafeArea(.all)
            .galleryPage("Conversation")
            // The field grows with its lines, and the bar with it; the rows
            // pass under the bar, blurred behind the field in what the window
            // is made of.
            .bottomBar(edge: edge) {
                Grid {
                    ZStack {
                        TextEditor($draft)
                            .placeholder("Message")
                            .growsWithText(true)
                    }
                    .background(window.background ?? .blur(.thin.tint(Palette.field)))
                    .shape(.roundedRectangle(10))
                    Button("Send")
                        .onClicked {
                            guard !draft.isEmpty else { return }
                            messages.append(draft)
                            draft = ""
                        }
                        .verticalAlignment(.end)
                        .gridColumn(1)
                }
                .columns(.fill, .auto)
                .columnSpacing(10)
                .padding(12)
            }
        } destination: { _ in
            Text("")
        }
    }
    // listing: end

    var notes: (any View)? {
        Text("Choose how the rows show at the bar's edge, open the conversation and scroll; at its end write a few "
            + "lines: the bar grows with them, and the last message stays in sight.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
