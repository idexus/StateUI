import StateUI

/// MAUI: NavigationPage.TitleView, holding a SearchBar.
///
/// **Why a view on the bar.** MAUI's platform-drawn search box,
/// `SearchHandler`, is a Shell feature and nothing else -
/// `Shell.SetSearchHandler`, suggestions in a dropdown the platform draws.
/// This library has no Shell, so the honest answer is the one a MAUI
/// application without one has: a view ON THE BAR, in place of the title,
/// holding an ordinary SearchBar - and the suggestions drawn where the app
/// draws everything else.
struct SearchSample: SampleContent {
    /// Where the gallery is: choosing a suggestion pushes a page.
    let nav: Navigation

    /// What there is to search. A constant: the sample is about the box, and
    /// nothing here edits the list.
    private let items = ["Alpha", "Beta", "Gamma", "Delta"]

    @State private var query = ""

    static let id = "search"
    static let title = "Search"
    static let summary = "A view on the navigation bar in place of the title, and the matches under it."

    static let code = """
        @State private var query = ""

        // MAUI hangs a title view off the PAGE, so it is asked for here rather
        // than written into the content - the same reason a toolbar item is.
        var navigationPageTitleView: Element? {
            SearchBar($query)
                .placeholder("Search the list")
                .backgroundColor(Palette.surface)
                .heightRequest(38)
        }

        var content: Element {
            VStack {
                ForEach(matches, id: \\.self) { item in
                    Button(item)
                        .onClicked { nav.push(.item(item)) }
                }

                Button("Clear")
                    .isEnabled(!query.isEmpty)
                    .onClicked { query = "" }
            }
        }

        /// What the query matches. A suggestion list of everything is noise, so
        /// an empty query matches the whole list and says so instead.
        private var matches: [String] {
            query.isEmpty
                ? items
                : items.filter { $0.lowercased().hasPrefix(query.lowercased()) }
        }
        """

    /// The page this sample sits on puts this on its bar, in place of its title.
    ///
    /// A view, not a handler: whatever is written here is an ordinary part of
    /// the tree, reading the same `@State` the content reads and rendered by the
    /// same renderer. The bar is simply where it is placed.
    var navigationPageTitleView: Element? {
        SearchBar($query)
            .placeholder("Search the list")
            .textColor(Palette.text)
            .placeholderColor(Palette.subtle)
            .backgroundColor(Palette.surface)
            .heightRequest(38)
            .verticalOptions(.center)
    }

    var content: Element {
        VStack {
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

            Label("`SearchHandler` is MAUI's own search box, and it belongs to the "
                + "Shell: a class to subclass, a dropdown the platform draws, and a "
                + "selection reported back. This library has no Shell; what is here is what "
                + "a MAUI app without one does - `NavigationPage.TitleView` holding a "
                + "SearchBar - and it is less machinery, not more: the suggestions are "
                + "rows this page draws, so they look like the app rather than like the "
                + "platform.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("A title view REPLACES the title, so this page has no name in the bar "
                + "while it is showing. That is MAUI's model and the reason to write one "
                + "only where the bar is doing a job.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("`SoftInput.hide()` still asks for the keyboard down where a page needs "
                + "it: only iOS and Mac Catalyst hear the focus half, and Android hears "
                + "only the keyboard half - see Core/Focus.swift.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }

    /// What the query matches - everything when there is no query, which is the
    /// difference from a suggestion dropdown: these rows are the page's content,
    /// and an empty page under an empty box would read as a mistake.
    ///
    /// `hasPrefix` rather than `contains`: the string overload of `contains`
    /// arrived in iOS 16 and this library's floor is 15.
    private var matches: [String] {
        query.isEmpty
            ? items
            : items.filter { $0.lowercased().hasPrefix(query.lowercased()) }
    }
}
