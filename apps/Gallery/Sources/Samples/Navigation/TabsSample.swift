import StateUI

/// A native tab arrangement and the selection binding that says which tab is showing.
///
/// The example is not on this page, and it cannot be: a `TabbedView` is a PAGE,
/// so the honest demonstration is for a section of the gallery to be one. What
/// is here is the button that goes there, and the code that arranges it.
struct TabsSample: SampleContent, ExampleContent {
    let nav: Navigation

    static let id = "tabs"
    static let title = "Tabs"
    static let summary = "A section arranged as tabs instead of a stack - the selection is a binding of your own type."

    static let code = """
        enum DemoTab: Hashable {
            case stack
            case second

            // A tab the reader added, which is what makes the LIST something
            // that changes rather than a fixed set.
            case extra(Int)
        }

        // The tabs are STATE, so the list can change under a live selection.
        @State private var tabs: [DemoTab] = [.stack, .second]
        @State private var tab: DemoTab = .stack
        @State private var tabsPath: [Route] = []

        let nav: Navigation
        let style: SessionStyle

        // The tabs are a collection of YOUR type and the selection is a
        // binding of it - not an index somebody has to keep in step. The
        // choice is a modifier, the way every other choice here is.
        TabbedView(tabs) { which in
            switch which {
            case .stack:
                // A tab may hold a whole stack of its own. Its caption and
                // its picture are the TAB PAGE's - the stack's here, not
                // those of the page inside it.
                NavigationStack($tabsPath) {
                    TabsPage(nav: nav, path: $tabsPath)
                } destination: { route in
                    // The same closure the main stack uses, told which
                    // array the page it builds will be a member of.
                    page(for: route, path: $tabsPath)
                }
                .title("Stack")
                .iconImageSource(ImageSource(light: "tab_bar.png", dark: "tab_bar_dark.png"))

            case .second:
                SecondTabPage(nav: nav)

            case .extra(let number):
                TabsExtraPage(nav: nav, number: number)
            }
        }
        .selection($tab)
        .barBackgroundColor(style.accent.color)

        // Changing the list is changing an array. The selection is untouched
        // by any of it - it names a TAB, not a position.
        func addTab() {
            // One past the highest number in use, so no two tabs share one
            // however many are closed in between.
            let numbers = tabs.compactMap { which -> Int? in
                if case .extra(let number) = which { return number }
                return nil
            }

            tabs.append(.extra((numbers.max() ?? 0) + 1))
        }

        func reverseTabs() {
            tabs.reverse()
        }

        // And from here, one move:
        Button("Open the tabs")
            .onClicked { nav.open(.tabs) }
        """

    var content: any View {
        VStack {
            Button("Open the tabs")
                .background(Palette.accent)
                .textColor(.white)
                .cornerRadius(8)
                .padding(20, 10)
                .horizontalAlignment(.center)
                .onClicked { nav.open(.tabs) }
        }
        .spacing(12)
    }

    var notes: Element? {
        VStack {
            Label("A `TabbedView` is a page, so a section of this gallery is one: the "
                + "button opens a section arranged as tabs rather than as a stack. The "
                + "tabs are an array of your own type and the selection is a binding of "
                + "it, so moving the tabs from code is an assignment.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The binding is two-way: tapping a tab writes it, and on Android so does "
                + "swiping between them. Each tab keeps its own place because each stack "
                + "is its own array - push a page on the first tab, change tabs and come "
                + "back, and the page is still on top.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Every tab page carries a panel that adds, inserts, closes and reverses "
                + "tabs while one is showing. The selection names a tab, not a position, "
                + "so rearranging the list leaves it alone, and the panel warns the moment "
                + "the binding and the tab on screen disagree. `Reverse the tabs` from the "
                + "middle of three rebuilds the whole bar and leaves you on the same page.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Closing the tab you are on is the one move with nothing left to keep "
                + "showing: the first tab shows instead, and the binding follows it. The "
                + "menu draws no row for this section, so every tab page carries a button "
                + "back to the samples.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
