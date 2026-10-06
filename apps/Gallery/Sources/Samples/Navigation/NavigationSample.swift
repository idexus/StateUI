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
        // Gallery/MainPage.swift - the stack, over the gallery's own
        // `Navigation`, a class of states: the section is the ROOT the stack
        // stands on, and its path an array of the gallery's own `Route`.
        // `page(for:path:)` turns a route into a page, looking a sample up in
        // the catalog - an id it does not know is a page that says so.
        extension MainPage {
            @ViewBuilder
            func detail() -> some View {
                if case .tabs = nav.section {
                    tabs()
                } else {
                    NavigationStack(nav.$path) {
                        root()
                    } destination: { route in
                        page(for: route, path: nav.$path)
                    }
                }
            }
        }

        // And on this page, every move an assignment - `push` appends a
        // route, `home()` opens the section with an empty path:
        let nav: Navigation
        @State private var arrivals = 0

        VStack {
            // The stack and the arrivals are read in this closure, so it is
            // what a push and a pop build again.
            DebugInfoLabel()

            Button("Push a page")
                .onClicked { nav.push(.level(1)) }

            // Where am I? A question Swift answers, with no host in it.
            Text(here)

            Button("Go home, and count the visit")
                .onClicked {
                    nav.home()
                    arrivals += 1
                }

            Text("Arrived home \\(arrivals) time(s)")

            Button("Empty the stack")
                .onClicked { nav.path = [] }
        }

        var here: String {
            let place = switch nav.section {
            case .home: "home"
            case .hidden: "the unlisted page"
            case .tabs: "the tabs"
            }

            return nav.path.isEmpty
                ? "\\(place), nothing pushed"
                : "\\(place) + \\(nav.path.count): \\(nav.path.map { "\\($0)" }.joined(separator: " › "))"
        }
        """

    var body: some View {
        VStack {
            DebugInfoLabel()

            Button("Push a page")
                .background(Palette.accent)
                .textColor(.white)
                .shape(.roundedRectangle(8))
                .padding(horizontal: 20, vertical: 10)
                .horizontalAlignment(.center)
                .onClicked { nav.push(.level(1)) }

            // No act, no await, no question asked of the host: the answer is
            // the state this page is reading.
            Text(here)
                .fontSize(13)
                .fontFamily("Menlo")
                .textColor(Palette.accent)
                .horizontalTextAlignment(.center)

            Button("Go home, and count the visit")
                .padding(horizontal: 20, vertical: 10)
                .horizontalAlignment(.center)
                .onClicked {
                    nav.home()
                    arrivals += 1
                }

            Text("Arrived home \(arrivals) time(s)")
                .fontSize(13)
                .horizontalTextAlignment(.center)

            Button("Empty the stack")
                .padding(horizontal: 20, vertical: 10)
                .horizontalAlignment(.center)
                .onClicked { nav.path = [] }
        }
        .spacing(12)
    }

    var notes: (any View)? {
        VStack {
            Text("The stack is this array, so where the gallery is can be read, written, "
                + "tested and serialized in Swift - and the platform's own back gesture "
                + "writes it too, so the array is still the answer after a swipe.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Push the same route again from a pushed page and it builds another "
                + "page: identity on a stack is the depth together with the route, so two "
                + "`.level(2)` pages are two pages with `@State` of their own.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("`home()` is three assignments - the section, the empty path and the "
                + "closed menu - with nothing to await. `path = []` takes everything off, "
                + "this page and the group page under it included, so you land on the "
                + "home page. Assigning the state you want is the navigation, and the "
                + "host brings the native stack to it in one move.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }

    /// Where the user is, in words - the section and how deep above it.
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
