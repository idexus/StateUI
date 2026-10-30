import StateUI

/// A conversation whose field and Send button stand at the foot of its page: the bar grows with the field's lines and
/// stands on the keyboard, and at the conversation's end the last message stays in sight as it grows.
struct BottomBarSample: SampleContent, ExampleContent {
    // listing: BottomBarSample
    @State private var presented = false
    @State private var path: [Int] = []
    @State private var messages = Self.talk
    @State private var draft = ""
    /// The list of messages, which opening and Send scroll.
    @Aim(ItemsView<Int>.self) private var list
    /// How tall the field stands at one line: the least it has stood at.
    @State private var oneLine = 0.0
    @State private var edge = ScrollEdge.automatic
    static let edges: [ScrollEdge] = [.automatic, .hard, .none]

    /// One message: what it says, and whether it is ours.
    struct Message: Hashable {
        let text: String
        let mine: Bool
    }

    /// A conversation long enough to scroll under the bar.
    static let talk: [Message] = [
        ("Are we still on for Saturday?", false), ("Yes! Ten o'clock at the station?", true),
        ("Perfect. Should I bring anything?", false), ("Just good shoes - the trail is muddy after the rain.", true),
        ("Noted. How long is the walk?", false), ("About four hours there and back, with a stop for lunch.", true),
        ("Lunch where?", false), ("There's a hut at the top. They make the best soup.", true),
        ("Sold. Is Anna coming too?", false), ("She said she'd try, but she has a deadline.", true),
        ("Tell her the soup is non-negotiable.", false), ("Ha, I will.", true),
        ("What if it rains again?", false), ("Then we take the lower path through the forest.", true),
        ("You've thought of everything.", false), ("I've done this walk a few times.", true),
        ("Can you send me the map?", false), ("I'll send it tonight.", true),
        ("Thanks! See you Saturday.", false), ("See you - don't forget the shoes!", true),
    ].map { Message(text: $0.0, mine: $0.1) }

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
                // Theirs on the left, ours on the right; the list opens at
                // its end, and a message sent scrolls there.
                ItemsView(Array(messages.indices)) { index in
                    VStack { bubble(messages[index]) }
                        .padding(horizontal: 16, vertical: 4)
                }
                .itemsLayout(.list())
                .aim(list)
                .onCreated { try await list.scrollTo(messages.count - 1, anchor: .end) }
                .onChanged(messages.count, policy: .cancelPrevious) {
                    try await list.scrollTo(messages.count - 1, anchor: .end)
                }
            }
            .ignoresSafeArea(.all)
            .galleryPage("Conversation")
            // The field grows with its lines, and the bar with it; the rows
            // pass under the bar, and under the field's glass.
            .bottomBar(edge: edge) {
                Grid {
                    ZStack {
                        TextEditor($draft)
                            .placeholder("Message")
                            .growsWithText(true)
                            .background(Color.transparent)
                    }
                    // The field's own ground is glass, its words clear of the
                    // round ends: a capsule at one line, its corners rounding
                    // alike as more lines grow it.
                    .padding(horizontal: 7, vertical: 0)
                    .background(.glass(.regular.isInteractive(true)))
                    .shape(.roundedRectangle(oneLine / 2))
                    .onFrameChanged { frame in
                        if oneLine == 0 || frame.height < oneLine { oneLine = frame.height }
                    }
                    Button("Send")
                        .onClicked {
                            guard !draft.isEmpty else { return }
                            messages.append(Message(text: draft, mine: true))
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

    /// A message in its bubble, at its side of the conversation.
    private func bubble(_ message: Message) -> some View {
        ZStack {
            Text(message.text)
                .textColor(message.mine ? Palette.onAccent : Palette.text)
        }
        .padding(horizontal: 12, vertical: 8)
        .background(message.mine ? Palette.accent : Palette.raised)
        // A capsule at one line - a corner never rounds past half the
        // height - and round corners on more.
        .shape(.roundedRectangle(20))
        .maximumWidth(300)
        .horizontalAlignment(message.mine ? .end : .start)
    }
    // listing: end

    var notes: (any View)? {
        Text("Choose how the rows show at the bar's edge, open the conversation and scroll; at its end write a few "
            + "lines: the bar grows with them, and the last message stays in sight. Send adds yours on the right "
            + "and takes the conversation to its end.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
