import StateUI

/// A search box on the page, narrowing a list as the user types.
struct SearchFieldSample: SampleContent, ExampleContent {
    // listing: SearchFieldSample
    @State private var query = ""
    @State private var searched = ""
    // listing: end

    static let id = "searchField"
    static let title = "SearchField"
    static let summary = "A TextField that says what it is for, on the page rather than in the navigation bar."

    // listing: SearchFieldSample
    var body: some View {
        VStack {
            // The list below is filtered from `query`, so every keystroke builds
            // this closure; the fields themselves are handed the state.
            DebugInfoLabel()

            // Every keystroke lands on `query`; `.onSubmitted` hears the
            // keyboard's search key.
            SearchField($query)
                .accessibilityIdentifier("searchBar.query")
                .accessibilityLabel("Search the list")
                .placeholder("Search the list")
                .onSubmitted { searched = query }

            VStack {
                ForEach(matches) { item in
                    Text(item)
                        .fontSize(15)
                        .padding(horizontal: 8, vertical: 4)
                        .id(item)
                }
            }
            .spacing(4)

            Text(searched.isEmpty
                ? "Type to narrow the list, then press the keyboard's search key."
                : "Searched for: \(searched)")
                .fontSize(12)
                .textColor(Palette.subtle)

            SectionTitle("In the accent")

            SearchField($query)
                .accessibilityIdentifier("searchBar.query.styled")
                .accessibilityLabel("Search the list, coloured")
                .placeholder("Search the list")
                .tint(Palette.accent)
        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("Two events: `.onTextChanged` on every edit - which runs after the binding "
                + "has landed the words on `query` - and `.onSubmitted` when the "
                + "user says they mean it.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("The same query, drawn twice. Type something: where the platform draws "
                + "a clear button, it appears once there is text to clear.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("The icons are the platform's, and a `SearchField` has no picture to put "
                + "in their place.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("This is the box that lives IN a page. The same control goes ON the "
                + "navigation bar as a page's title view - see Search, in the Navigation "
                + "group.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }

    // listing: SearchFieldSample
    /// What the query matches, or everything when there is no query - a search
    /// box that hides the list until something is typed says nothing about the
    /// list.
    private var matches: [String] {
        let items = ["Alpha", "Alma", "Beta", "Gamma", "Delta"]

        return query.isEmpty
            ? items
            : items.filter { $0.lowercased().hasPrefix(query.lowercased()) }
    }
    // listing: end
}
