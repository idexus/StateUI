import StateUI

/// A native navigation stack kept in step with one application array.
struct NavigationSample: SampleContent, ExampleContent {
    /// Where the gallery is. Borrowed, not held: this sample can move the
    /// application and READ where it is, and it cannot keep a stale copy of
    /// either.
    let nav: Navigation

    @State private var arrivals = 0

    static let id = "navigation"
    static let title = "Navigation stack"
    static let summary = "The stack is an array of your own type, and every move is an assignment."

    static let code = """
        enum Route: Hashable {
            case sample(String)
            case level(Int)
        }

        // The ROOT the stack stands on, the stack itself and the menu beside
        // them. Going home is three assignments - the section, the empty path
        // and the closed menu.
        @State private var section = "home"
        @State private var path: [Route] = []
        @State private var menuOpen = false
        @State private var arrivals = 0

        let catalog: Catalog
        let nav: Navigation

        NavigationStack($path) {
            HomePage(catalog: catalog, nav: nav)
        } destination: { route in
            switch route {
            case .sample(let id):
                // Looked up in the catalog - an id it does not know is a page
                // that says so.
                guard let sample = catalog.sample(id: id) else {
                    return MissingPage(id: id, nav: nav, path: $path)
                }

                return SamplePage.shown(sample, nav: nav)

            case .level(let n):
                return LevelPage(level: n, nav: nav, path: $path)
            }
        }
        .barBackgroundColor(AppColors.violet)
        .barTextColor(Palette.onBrand)

        // Every move there is, from this page. The stack and the arrivals are
        // read wherever they are printed, so that closure is what a push and
        // a pop build again.
        DebugInfoLabel()

        Button("Push a page")
            .onClicked { path.append(.level(1)) }

        // On LevelPage:
        Button("Back")
            .onClicked { path.removeLast() }

        Button("Go home, and count the visit")
            .onClicked {
                section = "home"
                path = []
                menuOpen = false
                arrivals += 1
            }

        Button("Empty the stack")
            .onClicked { path = [] }

        // Where am I? A question Swift answers, with no host in it:
        Label("\\(path.count) page(s) on top of \\(section)")
        Label("Arrived home \\(arrivals) time(s)")
        """

    var content: any View {
        VStack {
            DebugInfoLabel()

            Button("Push a page")
                .backgroundColor(Palette.accent)
                .textColor(.white)
                .cornerRadius(8)
                .padding(20, 10)
                .horizontalOptions(.center)
                .onClicked { nav.push(.level(1)) }

            // No act, no await, no question asked of the host: the answer is
            // the state this page is reading.
            Label(here)
                .fontSize(13)
                .fontFamily("Menlo")
                .textColor(Palette.accent)
                .horizontalTextAlignment(.center)

            Button("Go home, and count the visit")
                .padding(20, 10)
                .horizontalOptions(.center)
                .onClicked {
                    nav.home()
                    arrivals += 1
                }

            Label("Arrived home \(arrivals) time(s)")
                .fontSize(13)
                .horizontalTextAlignment(.center)

            Button("Empty the stack")
                .padding(20, 10)
                .horizontalOptions(.center)
                .onClicked { nav.path = [] }
        }
        .spacing(12)
    }

    var notes: Element? {
        VStack {
            Label("The stack is this array, so where the gallery is can be read, written, "
                + "tested and serialized in Swift - and the platform's own back gesture "
                + "writes it too, so the array is still the answer after a swipe.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Push the same route again from a pushed page and it builds another "
                + "page: identity on a stack is the depth together with the route, so two "
                + "`.level(2)` pages are two pages with `@State` of their own.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("`home()` is three assignments - the section, the empty path and the "
                + "closed menu - with nothing to await. `path = []` takes everything off, "
                + "this page and the group page under it included, so you land on the "
                + "home page. Assigning the state you want is the navigation, and the "
                + "host brings the native stack to it in one move.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }

    /// Where the reader is, in words - the section and how deep above it.
    ///
    /// Read from the same state the arrangement is built from, which is the
    /// whole point: there is one answer and it cannot drift from the screen.
    private var here: String {
        let place = switch nav.section {
        case .home: "home"
        case .hidden: "the unlisted page"
        case .tabs: "the tabs"
        }

        return nav.path.isEmpty
            ? "\(place), nothing pushed"
            : "\(place) + \(nav.path.count): \(nav.path.map { "\($0)" }.joined(separator: " › "))"
    }
}
