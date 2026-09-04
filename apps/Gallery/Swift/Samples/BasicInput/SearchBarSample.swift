import StateUI

/// MAUI: SearchBar.
struct SearchBarSample: SampleContent {
    @State private var query = ""
    @State private var searched = ""

    static let id = "searchBar"
    static let title = "SearchBar"
    static let summary = "An Entry that says what it is for, on the page rather than in the navigation bar."

    static let code = """
        @State private var query = ""
        @State private var searched = ""

        VStack {
            SearchBar($query)
                .placeholder("Search the list")
                .onSearchButtonPressed { searched = query }

            VStack {
                ForEach(matches) { item in
                    Label(item)
                        .id(item)
                }
            }

            Label(searched.isEmpty ? "nothing searched yet" : "Searched for: \\(searched)")

            // The same query again, with the platform's two icons tinted -
            // the magnifier at the front and the button that empties the
            // field.
            SearchBar($query)
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

    var example: Element {
        VStack {
            SearchBar($query)
                .placeholder("Search the list")
                .onSearchButtonPressed { searched = query }

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
                ? "The list narrows as you type. Press the keyboard's search key as well."
                : "Searched for: \(searched)")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Two events, both MAUI's: `textChanged` on every edit - which is what the "
                + "binding is - and `searchButtonPressed` when the reader says they mean "
                + "it.")
                .fontSize(12)
                .textColor(Palette.subtle)

            SectionTitle("THE MAGNIFIER AND THE CLEAR BUTTON")

            SearchBar($query)
                .placeholder("Search the list")
                .searchIconColor(Palette.accent)
                .cancelButtonColor(Palette.accent)
        }
        .spacing(12)
    }

    var notes: Element? {
        VStack {
            Label("The same query, drawn twice: the field above is left as the platform "
                + "draws it, and this one tints the two icons the platform puts in every "
                + "search box. Type something to bring the clear button out - it only "
                + "appears once there is text to clear.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Those two colours are the whole of what MAUI offers over the artwork: "
                + "the icons themselves are the platform's, and there is no picture to "
                + "put in their place.")
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
