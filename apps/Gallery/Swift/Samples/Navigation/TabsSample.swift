import StateUI

/// MAUI: TabbedPage, and the selection binding that says which tab is showing.
///
/// The example is not on this page, and it cannot be: a `TabbedPage` is a PAGE,
/// so the honest demonstration is for a section of the gallery to be one. What
/// is here is the button that goes there, and the code that arranges it.
struct TabsSample: SampleContent {
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

        // The tabs are a collection of YOUR type and the selection is a
        // binding of it - not an index somebody has to keep in step. The
        // choice is a modifier, the way every other choice here is.
        TabbedPage(tabs) { which in
            switch which {
            case .stack:
                // A tab may hold a whole stack of its own. Its caption and
                // its picture are the TAB PAGE's - the stack's here, not
                // those of the page inside it.
                NavigationPage($tabsPath) {
                    TabsPage(nav: nav, path: $tabsPath)
                } destination: { route in
                    // The same closure the main stack uses, told which
                    // array the page it builds will be a member of.
                    page(for: route, catalog, nav, path: $tabsPath)
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
        .selectedTabColor(Palette.accent)
        .unselectedTabColor(Palette.subtle)
        // A BRUSH, where barBackgroundColor takes one flat colour.
        .barBackground(.linearGradient([
            GradientStop(AppColors.violet, 0),
            GradientStop(Palette.accent, 1),
        ], startPoint: Point(0, 0), endPoint: Point(1, 0)))
        .barTextColor(Palette.onBrand)

        // Changing the list is changing an array. The selection is untouched
        // by any of it - it names a TAB, not a position.
        func addTab() {
            tabs.append(.extra((tabs.count)))
        }

        func reverseTabs() {
            tabs.reverse()
        }

        // And from here, one assignment:
        Button("Open the tabs")
            .onClicked { nav.open(.tabs) }
        """

    var content: Element {
        VStack {
            Button("Open the tabs")
                .backgroundColor(Palette.accent)
                .textColor(.white)
                .cornerRadius(8)
                .padding(20, 10)
                .horizontalOptions(.center)
                .onClicked { nav.open(.tabs) }

            Label("A TabbedPage is a page, so a section of this gallery simply IS one: "
                + "the menu chooses a section, and one of them arranges its pages as tabs "
                + "rather than as a stack. Every other section is a NavigationPage.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The tabs are a collection of the author's own type and the selection is "
                + "a binding of that type - the same rule a LazyList's selection follows. "
                + "What travels on the wire is an INDEX into the children the message just "
                + "described, because that is what MAUI's own model is.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("It is TWO-WAY: tapping a tab writes the binding, and on Android so does "
                + "swiping between them - there is no tap anywhere in that gesture, and it "
                + "arrives through the same channel as everything else. Writing the "
                + "binding from code moves the tabs the other way.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Each tab keeps its own place because the ARRAYS are separate: the first "
                + "tab holds a NavigationPage over a path of its own. Push a page there, "
                + "change tabs and come back - the page is still on top, and nothing in "
                + "the library decided that.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The LIST changes too, and every tab page carries the panel that does "
                + "it: add one at the end, insert one before the tab you are on, close "
                + "any of them, turn the whole list end for end. The tabs are an array in "
                + "`@State`, so all four are one line of ordinary Swift, and the selection "
                + "is untouched by any of them - it names a TAB, not a position.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The panel prints the number `selection` puts on the wire, and that "
                + "number is the whole reason this is worth pressing. A property is sent "
                + "only when its VALUE changed, so a move that leaves the showing tab at "
                + "the same INDEX sends no selection at all - and the tab bar is rebuilt "
                + "underneath one nobody restated. `Reverse the tabs` from the middle of "
                + "three is exactly that: index 1 before, index 1 after, nothing sent.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("What the panel is watching for is the two readings disagreeing - the "
                + "binding naming one tab while another is on screen. MAUI's own MultiPage "
                + "moves CurrentPage to the first child the moment the showing page leaves "
                + "the collection, which rearranging does to every page it has to move, so "
                + "the host remembers what was showing BEFORE it rearranges and puts that "
                + "same page back. Closing the tab you are ON is the case where there is "
                + "no answer to keep: the platform picks the first, says so, and the "
                + "binding follows it.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The way out is a button on those pages: the menu draws a row per group "
                + "and none for this section, which is this app's choice rather than a "
                + "rule: the menu is a page, and its rows are whatever it writes.")
                .fontSize(12)
                .textColor(Palette.subtle)

            SectionTitle("THE BAR ABOVE THESE TABS")

            Label("It runs violet to orange, and every other bar in this app is one flat "
                + "colour. That is the difference between the two properties: "
                + "`barBackgroundColor` takes a Color, `barBackground` takes a Brush - so "
                + "a gradient, or anything else a Brush can be. Both live on the "
                + "arrangement that draws the bar, never on a page under it.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
