import StateUI

/// A native tab arrangement and the selection binding that says which tab is showing.
///
/// The example is not on this page, and it cannot be: a `TabView` is a PAGE,
/// so the honest demonstration is for a section of the gallery to be one. What
/// is here is the button that goes there, and the code that arranges it.
struct TabsSample: SampleContent, ExampleContent {
    // listing: TabsSample
    let nav: Navigation
    // listing: end

    static let id = "tabs"
    static let title = "Tabs"
    static let summary = "A section arranged as tabs instead of a stack - the selection is a binding of your own type."

    static var code: String { Listings.joined("MainPage.tabs", "TabsSample") }

    // listing: TabsSample
    var body: some View {
        VStack {
            Button("Open the tabs")
                .background(Palette.accent)
                .textColor(.white)
                .shape(.roundedRectangle(8))
                .padding(horizontal: 20, vertical: 10)
                .horizontalAlignment(.center)
                .onClicked { nav.open(.tabs) }
        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("A `TabView` is a page, so a section of this gallery is one: the "
                + "button opens a section arranged as tabs rather than as a stack. The "
                + "tabs are an array of your own type and the selection is a binding of "
                + "it, so moving between them from code is an assignment.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("The binding is two-way: tapping a tab writes it. Each tab keeps its own "
                + "place because each stack is its own array - push a page on the first "
                + "tab, change tabs and come back, and the page is still on top.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Every tab page carries a panel that adds, inserts, closes and reverses "
                + "tabs while one is showing. The selection names a tab, not a position, "
                + "so rearranging the list leaves it alone, and the panel warns the moment "
                + "the binding and the tab on screen disagree. `Reverse the tabs` from the "
                + "middle of three rebuilds the whole bar and leaves you on the same page.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Closing the tab you are on is the one move with nothing left to keep "
                + "showing: the tab that takes its place shows instead, or the last one "
                + "where none does. The menu draws no row for this section, so every tab "
                + "page carries a button back to the samples.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
