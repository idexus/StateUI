import StateUI

/// One level of the drill-down. Every push makes another of these: identity on
/// a stack is the depth together with the route, so a stack may hold the same
/// route more than once and each is a page with `@State` of its own.
///
/// It also shows what a PAGE can still ask of the stack it is on, the bar
/// itself belonging to the arrangement: its view says those requests by
/// modifier.
struct LevelPage: View {
    /// The gallery this page is in - the scene its inspector button opens.
    @Environment(\.scene) var scene

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

    /// What this page asks of its stack's bar: to show, and to offer the way back.
    @State private var showsBar = true
    @State private var offersBack = true

    var body: some View {
        VStack {
            SectionTitle("Pushed page")

            Text("Level \(level)")
                .fontSize(32)
                .fontAttributes(.bold)
                .horizontalTextAlignment(.center)

            Text("appeared \(arrivals)× · disappeared \(departures)×")
                .fontSize(13)
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)

            Text("navigated to \(navigatedTo)× · leaving \(leaving)× · left \(left)×")
                .fontSize(13)
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)

            Button("Deeper")
                .background(Palette.accent)
                .textColor(.white)
                .shape(.roundedRectangle(8))
                .padding(horizontal: 20, vertical: 10)
                .horizontalAlignment(.center)
                .onClicked { path.append(.level(level + 1)) }

            Button("Back")
                .padding(horizontal: 20, vertical: 10)
                .horizontalAlignment(.center)
                .onClicked { path.removeLast() }

            SwitchRow("Bar", $showsBar)
            SwitchRow("Way back", $offersBack)

            Text("Go deeper and come back: the same page counts a second arrival.")
                .fontSize(12)
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)
        }
        .spacing(16)
        .padding(24)
        .galleryPage("Level \(level)")
        // What the back button reads while the page ABOVE this one is on
        // top - written on the page the user would go back to. A host
        // whose back affordance has no text ignores it.
        .backButtonTitle("Level \(level)")
        // The bar and its way back are the page's to ask for, each from the
        // state its switch writes: the host follows it, no view built again.
        .showsNavigationBar($showsBar)
        .showsBackButton($offersBack)
        // What this page sees of its own life, one count per moment. Appearing
        // and disappearing answer visibility; the other three answer a move.
        // `onAppearing` runs on every arrival, the first one included, which
        // makes it the moment to refresh what may have changed while the page
        // was covered.
        .onAppearing { arrivals += 1 }
        .onDisappearing { departures += 1 }
        .onNavigatedTo { navigatedTo += 1 }
        .onNavigatingFrom { leaving += 1 }
        .onNavigatedFrom { left += 1 }
    }
}
