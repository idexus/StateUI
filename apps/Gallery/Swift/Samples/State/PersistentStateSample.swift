import StateUI

/// How dark the gallery's own demonstration paints - kept as the text it is
/// spelled with, which is what makes conformance one line.
enum Shade: String, PersistentValue {
    case quiet
    case bold
}

extension PersistentKey {
    /// How many times the reader has pressed the button, ever.
    static let visits = PersistentKey("dev.stateui.gallery.visits", of: Int.self)

    /// What the reader is called.
    static let who = PersistentKey("dev.stateui.gallery.who", of: String.self)

    /// Whether the panel below paints loudly.
    static let shade = PersistentKey("dev.stateui.gallery.shade", of: Shade.self)
}

/// `@State` under a key is state the application KEEPS - the value is there
/// again the next time the app opens, with nothing to load and nothing to save.
struct PersistentStateSample: SampleContent {
    @State(.visits) private var visits = 0
    @State(.who) private var who = ""
    @State(.shade) private var shade = Shade.quiet

    static let id = "persistent-state"
    static let title = "Kept state"
    static let summary = "State under a key survives the app being closed."

    static let code = """
        // A key can hold what the platform's settings store holds - and an
        // enum over one of those is one line, kept as the text it is spelled
        // with.
        enum Shade: String, PersistentValue {
            case quiet
            case bold
        }

        extension PersistentKey {
            static let visits = PersistentKey("dev.stateui.gallery.visits", of: Int.self)
            static let who = PersistentKey("dev.stateui.gallery.who", of: String.self)
            static let shade = PersistentKey("dev.stateui.gallery.shade", of: Shade.self)
        }

        // On the Application, so the host knows what to read before the
        // first view is built:
        var persistentKeys: [PersistentKey] { [.visits, .who, .shade] }

        // And then it is ordinary state:
        @State(.visits) private var visits = 0
        @State(.who) private var who = ""
        @State(.shade) private var shade = Shade.quiet

        VStack {
            Label("Pressed \\(visits) times, ever")

            Button("Press")
                .onClicked { visits += 1 }

            Entry($who)
                .placeholder("Your name")

            Button(shade == .quiet ? "quiet" : "bold")
                .onClicked { shade = shade == .quiet ? .bold : .quiet }
        }
        """

    var notes: Element? {
        VStack {
            Label("Close the app completely and open it again: the count and the name "
                + "are where you left them.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The value written beside the state - `= 0` - is what it holds when "
                + "the store has nothing under that name, so the default stays where "
                + "it can be seen. Reading and writing are exactly what they are on any "
                + "other @State: nothing is awaited, and a write reaches the store by "
                + "itself.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The application LISTS its keys, in persistentKeys. That is not "
                + "ceremony: a settings store is read one key at a time and offers no "
                + "list of what it holds, so naming them is what puts the values in "
                + "memory before the first view asks for one.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("They are kept in the platform's own settings store - NSUserDefaults, "
                + "SharedPreferences, ApplicationDataContainer - beside whatever else "
                + "the app keeps there. So a key can hold only what such a store holds: "
                + "a whole number, a number, true or false, or text. An enum over one of "
                + "those is one line, as Shade is here.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }

    var content: Element {
        VStack {
            Label("Pressed \(visits) times, ever")
                .fontSize(22)
                .horizontalTextAlignment(.center)

            HStack {
                Button("Press")
                    .backgroundColor(Palette.accent)
                    .cornerRadius(8)
                    .padding(20, 10)
                    .onClicked { visits += 1 }

                Button("Start over")
                    .borderColor(Palette.outline)
                    .borderWidth(1)
                    .backgroundColor(.transparent)
                    .textColor(Palette.subtle)
                    .cornerRadius(8)
                    .padding(20, 10)
                    .isEnabled(visits != 0)
                    .onClicked { visits = 0 }
            }
            .spacing(12)
            .horizontalOptions(.center)

            Entry($who)
                .placeholder("Your name")

            Label(who.isEmpty ? "Welcome back" : "Welcome back, \(who)")
                .fontSize(17)
                .horizontalTextAlignment(.center)

            // A key whose value is an enum - kept as the word it is spelled
            // with, so anything else that opens the store can read it.
            HStack {
                Label("Shade")
                    .verticalOptions(.center)

                Button(shade == .quiet ? "quiet" : "bold")
                    .borderColor(Palette.outline)
                    .borderWidth(1)
                    .backgroundColor(.transparent)
                    .textColor(Palette.subtle)
                    .cornerRadius(8)
                    .padding(16, 8)
                    .onClicked { shade = shade == .quiet ? .bold : .quiet }
            }
            .spacing(12)

            BoxView()
                .heightRequest(48)
                .color(shade == .bold ? Palette.accent : Palette.surface)
                .cornerRadius(8)
        }
        .spacing(14)
    }
}
