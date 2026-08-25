import StateUI

/// MAUI: NavigationPage, and the array this side keeps it in step with.
struct NavigationSample: SampleContent {
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

        // The ROOT the stack stands on, and the stack itself. Going home is
        // two assignments - the section, and the empty path.
        @State private var section = "home"
        @State private var path: [Route] = []
        @State private var arrivals = 0

        NavigationPage($path) {
            HomePage(nav: nav)
        } destination: { route in
            switch route {
            case .sample(let id): SamplePage(id: id, nav: nav)
            case .level(let n):   LevelPage(level: n, path: $path)
            }
        }
        .barBackgroundColor(AppColors.violet)
        .barTextColor(Palette.onBrand)

        // -- EVERY MOVE THERE IS --

        Button("Push a page")
            .onClicked { path.append(.level(1)) }

        Button("Back")
            .onClicked { path.removeLast() }

        Button("Go home, and count the visit")
            .onClicked {
                section = "home"
                path = []
                arrivals += 1
            }

        Button("Empty the stack")
            .onClicked { path = [] }

        // Where am I? A question this side answers, with no host in it:
        Label("\\(path.count) page(s) on top of \\(section)")
        Label("Arrived home \\(arrivals) time(s)")
        """

    var content: Element {
        VStack {
            Button("Push a page")
                .backgroundColor(Palette.accent)
                .textColor(.white)
                .cornerRadius(8)
                .padding(20, 10)
                .horizontalOptions(.center)
                .onClicked { nav.push(.level(1)) }

            Label("Push the same route again from there and it builds ANOTHER page - "
                + "identity on a stack is the depth TOGETHER WITH the route, so two "
                + "`.level(2)` pages are two pages with `@State` of their own.")
                .fontSize(12)
                .textColor(Palette.subtle)

            SectionTitle("WHERE AM I?")

            // No act, no await, no question asked of MAUI: the answer is the
            // state this page is reading, and it is right by the time the
            // screen has caught up with it.
            Label(here)
                .fontSize(13)
                .fontFamily("Menlo")
                .textColor(Palette.accent)

            Label("The stack IS this array, so where the application is can be read, "
                + "written, tested and serialized on this side - and the platform's own "
                + "back gesture writes it too, so the array is still the answer after a "
                + "swipe nobody asked this app about.")
                .fontSize(12)
                .textColor(Palette.subtle)

            SectionTitle("GOING HOME")

            Button("Go home, and count the visit")
                .padding(20, 10)
                .horizontalOptions(.center)
                .onClicked {
                    nav.home()
                    arrivals += 1
                }

            Label("Arrived home \(arrivals) time(s) from here. `home()` is two "
                + "assignments - the section, and the empty path - with nothing to await "
                + "and nothing to undo along the way.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Button("Empty the stack")
                .padding(20, 10)
                .horizontalOptions(.center)
                .onClicked { nav.path = [] }
        }
        .spacing(12)
    }

    var notes: Element? {
        Label("`path = []` takes everything off, including this page - so you land "
            + "on the list this sample was opened from. There is no PopToRoot to "
            + "call: assigning the state you want IS the navigation, and the host "
            + "reconciles the native stack to it in one move.")
            .fontSize(12)
            .textColor(Palette.subtle)
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
