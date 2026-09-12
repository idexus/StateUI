import StateUI

/// MAUI: NavigationPage.TitleView, holding a SearchBar.
///
/// **Why a view on the bar.** A search box belongs where the reader looks for
/// it, which is the navigation bar, and a bar can hold a VIEW in place of its
/// title - so the box is an ordinary `SearchBar` put there, and the suggestions
/// under it are ordinary rows this page draws. Nothing about either is special
/// to searching, which is the point: the app decides what a suggestion looks
/// like and what choosing one does.
struct SearchSample: SampleContent {
    /// Where the gallery is: choosing a suggestion pushes a page.
    let nav: Navigation

    /// What there is to search. A constant: the sample is about the box, and
    /// nothing here edits the list.
    private let items = ["Alpha", "Beta", "Gamma", "Delta"]

    @State private var query = ""

    /// The page this sample is on, whose bar the box goes on.
    @Environment private var page: PageSession

    static let id = "search"
    static let title = "Search"
    static let summary = "A view on the navigation bar in place of the title, and the matches under it."

    static let code = """
        let nav: Navigation
        private let items = ["Alpha", "Beta", "Gamma", "Delta"]

        @State private var query = ""

        @Environment private var page: PageSession

        var content: any View {
            VStack {
                // The query and the matches are read here, so every keystroke
                // in the bar builds this closure.
                DebugInfoLabel()

                ForEach(matches, id: \\.self) { item in
                    MenuRow(item) { nav.push(.item(item)) }
                }

                Button("Clear")
                    .isEnabled(!query.isEmpty)
                    .onClicked { query = "" }
            }
            // MAUI hangs a title view off the PAGE, so it is written into the
            // page's session - the same reason a toolbar item is.
            .onCreated {
                page.navigationPageTitleView = SearchBar($query)
                    .placeholder("Search the list")
                    .backgroundColor(Palette.surface)
                    .heightRequest(38)
            }
        }

        /// What the query matches - everything when there is no query: these
        /// rows are the page's content, and an empty page under an empty box
        /// would read as a mistake.
        private var matches: [String] {
            query.isEmpty
                ? items
                : items.filter { $0.lowercased().hasPrefix(query.lowercased()) }
        }
        """

    var content: any View {
        VStack {
            DebugInfoLabel()

            Label("The box is on the navigation bar, where the page's title would be. "
                + "Type, and these rows follow it.")
                .fontSize(14)

            VStack {
                ForEach(matches, id: \.self) { item in
                    // A row that opens a page: the chosen item rides as a VALUE
                    // of the route - `.item("Alpha")` - so nothing about it is
                    // a string in a dictionary.
                    MenuRow(item) { nav.push(.item(item)) }
                }
            }
            .spacing(2)

            Label(matches.isEmpty
                ? "Nothing matches \"\(query)\""
                : "\(matches.count) of \(items.count) shown")
                .fontSize(12)
                .textColor(Palette.subtle)

            Button("Clear the box")
                .isEnabled(!query.isEmpty)
                .padding(20, 10)
                .horizontalOptions(.center)
                .onClicked { query = "" }

        }
        .spacing(12)
        // The box goes on the page's BAR, in place of its title - MAUI hangs
        // a title view off the page, so it is written into the page's
        // session. A view rather than a value: an ordinary part of the tree,
        // handed the same `@State` the content reads.
        .onCreated {
            page.navigationPageTitleView = SearchBar($query)
                .automationId("search.query")
                .semanticDescription("Search the list")
                .placeholder("Search the list")
                .textColor(Palette.text)
                .placeholderColor(Palette.subtle)
                .backgroundColor(Palette.surface)
                .heightRequest(38)
                .verticalOptions(.center)
        }
    }

    var notes: Element? {
        VStack {
            Label("The box is a `SearchBar` handed to `NavigationPage.TitleView`, which "
                + "is the bar's title slot - so it sits where this page's title would; the "
                + "page a match pushes wears its own. The suggestions are rows this page "
                + "draws from its own state, which is why they can look like the app and "
                + "do whatever choosing one should do.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("A title view REPLACES the title, so this page has no name in the bar "
                + "while it is showing. That is MAUI's model and the reason to write one "
                + "only where the bar is doing a job.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("`SoftInput.hide()` takes the focus off whatever holds it - the box on "
                + "the bar included. On iOS a focused search box takes over the bar, back "
                + "button and all, and unfocusing it gives the bar back.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }

    /// What the query matches - everything when there is no query, which is the
    /// difference from a suggestion dropdown: these rows are the page's content,
    /// and an empty page under an empty box would read as a mistake.
    ///
    /// `hasPrefix` rather than `contains`, which is a choice about the RESULT
    /// and not about what compiles: matching from the start makes a short list
    /// of names narrow predictably as the reader types, where a substring
    /// match keeps rows whose beginning bears no relation to the query.
    private var matches: [String] {
        query.isEmpty
            ? items
            : items.filter { $0.lowercased().hasPrefix(query.lowercased()) }
    }
}
