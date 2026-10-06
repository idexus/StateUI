import StateUI

/// A native tab arrangement and the selection binding that says which tab is showing.
///
/// The example is not on this page, and it cannot be: a `TabView` is a PAGE,
/// so the honest demonstration is for a section of the gallery to be one. What
/// is here is the button that goes there, and the code that arranges it.
struct TabsSample: SampleContent, ExampleContent {
    let nav: Navigation

    static let id = "tabs"
    static let title = "Tabs"
    static let summary = "A section arranged as tabs instead of a stack - the selection is a binding of your own type."

    static let code = """
        // Gallery/MainPage.swift - a section arranged as tabs. The tabs are a
        // collection of the gallery's own type, `DemoTab` (.stack, .second,
        // and .extra(Int) for a tab the user added), kept as STATE of its
        // `Navigation` - so the list can change under a live selection - and
        // the selection is a binding of it, not an index somebody has to keep
        // in step. The choice is a modifier, the way every other choice is.
        extension MainPage {
            func tabs() -> some View {
                TabView(nav.tabs) { which in
                    switch which {
                    case .stack:
                        // A tab may hold a whole stack of its own. Its caption
                        // and its picture are the TAB PAGE's - the stack's
                        // here, not those of the page inside it.
                        NavigationStack(nav.$tabsPath) {
                            TabsPage(nav: nav, path: nav.$tabsPath)
                        } destination: { route in
                            // The same closure the main stack uses, told which
                            // array the page it builds will be a member of.
                            page(for: route, path: nav.$tabsPath)
                        }
                        .title("Stack")
                        .icon(ImageSource(light: "tab_bar.png", dark: "tab_bar_dark.png"))

                    case .second:
                        SecondTabPage(nav: nav)

                    case .extra(let number):
                        TabsExtraPage(nav: nav, number: number)
                    }
                }
                .selection(nav.$tab)
            }
        }

        // On a tab, changing the list is changing an array - `Navigation`'s
        // addTab, insertTab and reverseTabs. The selection is untouched by any
        // of it: it names a TAB, not a position.

        // And from here, one move:
        let nav: Navigation

        Button("Open the tabs")
            .onClicked { nav.open(.tabs) }
        """

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

    var notes: (any View)? {
        VStack {
            Text("A `TabView` is a page, so a section of this gallery is one: the "
                + "button opens a section arranged as tabs rather than as a stack. The "
                + "tabs are an array of your own type and the selection is a binding of "
                + "it, so moving the tabs from code is an assignment.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("The binding is two-way: tapping a tab writes it, and on Android so does "
                + "swiping between them. Each tab keeps its own place because each stack "
                + "is its own array - push a page on the first tab, change tabs and come "
                + "back, and the page is still on top.")
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
                + "showing: the first tab shows instead, and the binding follows it. The "
                + "menu draws no row for this section, so every tab page carries a button "
                + "back to the samples.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
