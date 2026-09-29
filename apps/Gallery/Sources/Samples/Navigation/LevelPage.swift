import StateUI

/// One level of the drill-down. Every push makes another of these: identity on
/// a stack is the depth together with the route, so a stack may hold the same
/// route more than once and each is a page with `@State` of its own.
///
/// It also shows what a PAGE can still ask of the stack it is on, the bar
/// itself belonging to the arrangement: those requests are written into the
/// page session.
struct LevelPage: ContentView {
    /// The gallery this page is in - the scene its inspector button opens.
    @Environment var scene: SceneSession

    /// The page itself - what it is called, and its buttons.
    @Environment private var page: PageSession

    let level: Int

    let nav: Navigation

    /// The stack this page is ON - the main one, or the one inside a tab. A
    /// page that pushes and pops writes the array it is a member of, which is
    /// why this is a binding rather than a call to something global.
    ///
    /// The platform's own back arrow, its swipe and its system back gesture
    /// write the same array: the host reports the depth that survived and the
    /// array is truncated to match. A gesture let go halfway reports nothing,
    /// because nothing happened.
    @Binding var path: [Route]

    /// What this page has SEEN of its own life. `@State`, so it belongs to
    /// this page and survives being covered - which is the whole point: going
    /// deeper and coming back is a departure and a second arrival on the SAME
    /// page, not a new one.
    @State private var arrivals = 0
    @State private var departures = 0

    /// The same life, counted the OTHER way: these three answer a MOVE and
    /// nothing else, where appearing also answers the page coming back for a
    /// reason that was never one - the application waking, a tab bar
    /// rebuilding. Side by side, the difference is the whole lesson.
    @State private var navigatedTo = 0
    @State private var leaving = 0
    @State private var left = 0

    var content: any View {
        VStack {
            SectionTitle("Pushed page")

            Label("Level \(level)")
                .fontSize(32)
                .fontAttributes(.bold)
                .horizontalTextAlignment(.center)

            Label("appeared \(arrivals)× · disappeared \(departures)×")
                .fontSize(13)
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)

            Label("navigated to \(navigatedTo)× · leaving \(leaving)× · left \(left)×")
                .fontSize(13)
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)

            Button("Deeper")
                .background(Palette.accent)
                .textColor(.white)
                .shape(.roundedRectangle(8))
                .padding(20, 10)
                .horizontalAlignment(.center)
                .onClicked { path.append(.level(level + 1)) }

            Button("Back")
                .padding(20, 10)
                .horizontalAlignment(.center)
                .onClicked { path.removeLast() }

            Label("Go deeper and come back: the same page counts a second arrival.")
                .fontSize(12)
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)
        }
        .spacing(16)
        .padding(24)
        .onCreated {
            page.gallery("Level \(level)", scene: scene, nav: nav)

            // What the back button reads while the page ABOVE this one is on
            // top - written on the page the user would go back to. A host
            // whose back affordance has no text ignores it.
            page.backButtonTitle = "Level \(level)"
        }
        // What this page sees of its own life, one count per moment. Appearing
        // and disappearing answer visibility; the other three answer a move.
        // `appearing` comes on every arrival, the first one included, which
        // makes it the moment to refresh what may have changed while the page
        // was covered.
        .onChanged(page.phase) {
            switch page.phase {
            case .appearing: arrivals += 1
            case .disappearing: departures += 1
            case .navigatedTo: navigatedTo += 1
            case .navigatingFrom: leaving += 1
            case .navigatedFrom: left += 1
            case .created: break
            }
        }
    }
}
