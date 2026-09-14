import StateUI

/// A search box on the page, narrowing a list as the reader types.
struct SearchFieldSample: SampleContent, ExampleContent {
    @State private var query = ""
    @State private var searched = ""

    static let id = "searchField"
    static let title = "SearchField"
    static let summary = "A TextField that says what it is for, on the page rather than in the navigation bar."

    static let code = """
        @State private var query = ""
        @State private var searched = ""

        VStack {
            // The list below is filtered from `query`, so every keystroke builds
            // this closure; the bar itself is handed the state.
            DebugInfoLabel()

            SearchField($query)
                .placeholder("Search the list")
                .onSubmitted { searched = query }

            VStack {
                ForEach(matches) { item in
                    Label(item)
                        .id(item)
                }
            }

            Label(searched.isEmpty
                ? "Type to narrow the list, then press the keyboard's search key."
                : "Searched for: \\(searched)")

            // The same query again, with the platform's two icons tinted -
            // the magnifier at the front and the button that empties the
            // field.
            SearchField($query)
                .placeholder("Search the list")
                .searchIconColor(Palette.accent)
                .cancelButtonColor(Palette.accent)
        }

        /// What the query matches, or everything when there is no query.
        private var matches: [String] {
            let items = ["Alpha", "Alma", "Beta", "Gamma", "Delta"]

            return query.isEmpty
                ? items
                : items.filter { $0.lowercased().hasPrefix(query.lowercased()) }
        }
        """

    var content: any View {
        VStack {
            DebugInfoLabel()

            SearchField($query)
                .accessibilityIdentifier("searchBar.query")
                .accessibilityLabel("Search the list")
                .placeholder("Search the list")
                .onSubmitted { searched = query }

            VStack {
                ForEach(matches) { item in
                    Label(item)
                        .fontSize(15)
                        .padding(8, 4)
                        .id(item)
                }
            }
            .spacing(4)

            Label(searched.isEmpty
                ? "Type to narrow the list, then press the keyboard's search key."
                : "Searched for: \(searched)")
                .fontSize(12)
                .textColor(Palette.subtle)

            SectionTitle("The magnifier and the clear button")

            SearchField($query)
                .accessibilityIdentifier("searchBar.query.styled")
                .accessibilityLabel("Search the list, coloured")
                .placeholder("Search the list")
                .searchIconColor(Palette.accent)
                .cancelButtonColor(Palette.accent)
        }
        .spacing(12)
    }

    var notes: Element? {
        VStack {
            Label("Two events: `.onTextChanged` on every edit - which runs after the binding "
                + "has landed the words on `query` - and `.onSubmitted` when the "
                + "reader says they mean it.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The same query, drawn twice: the first field is left as the platform "
                + "draws it, and the second tints the two icons the platform puts in every "
                + "search box. Type something to bring the clear button out - it only "
                + "appears once there is text to clear.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Those two colours are all a `SearchField` offers over the artwork: the "
                + "icons themselves are the platform's, and there is no picture to put in "
                + "their place.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("This is the box that lives IN a page. The same control goes ON the "
                + "navigation bar as a page's title view - see Search, in the Navigation "
                + "group.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }

    /// What the query matches, or everything when there is no query - a search
    /// box that hides the list until something is typed says nothing about the
    /// list.
    private var matches: [String] {
        let items = ["Alpha", "Alma", "Beta", "Gamma", "Delta"]

        return query.isEmpty
            ? items
            : items.filter { $0.lowercased().hasPrefix(query.lowercased()) }
    }
}
