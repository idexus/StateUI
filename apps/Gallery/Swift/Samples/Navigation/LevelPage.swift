import StateUI

/// One level of the drill-down. Every push makes another of these.
///
/// It also shows what a PAGE can still ask of the stack it is on, now that the
/// bar itself belongs to the arrangement: MAUI's `NavigationPage` attached
/// properties, written on the page as they are in XAML - the `navigationPage`
/// prefix being the type that declares them, the way `.gridRow` is Grid.Row.
struct LevelPage: GalleryPage {
    let level: Int

    let nav: Navigation

    /// The stack this page is ON - the main one, or the one inside a tab. A
    /// page that pushes and pops writes the array it is a member of, which is
    /// why this is a binding rather than a call to something global.
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

    var title: String? { "Level \(level)" }

    /// MAUI's Page.Appearing, which fires on EVERY arrival - the first one and
    /// every return from a page pushed over this one.
    var onAppearing: EventHandler? {
        { arrivals += 1 }
    }

    /// And its mirror. MAUI: Page.Disappearing.
    var onDisappearing: EventHandler? {
        { departures += 1 }
    }

    /// A move has ARRIVED here. MAUI: Page.NavigatedTo.
    var onNavigatedTo: EventHandler? {
        { navigatedTo += 1 }
    }

    /// A move is about to leave, and this page is still the one on screen -
    /// which is what makes it the place to put away what must not travel.
    /// MAUI: Page.NavigatingFrom.
    var onNavigatingFrom: EventHandler? {
        { leaving += 1 }
    }

    /// The move has left; the destination is already showing.
    /// MAUI: Page.NavigatedFrom.
    var onNavigatedFrom: EventHandler? {
        { left += 1 }
    }

    /// What the back button says on the page ABOVE this one - written on the
    /// page you would go BACK TO, which is iOS's model. Android and Windows
    /// draw an arrow with nowhere to put words and ignore it.
    var navigationPageBackButtonTitle: String? { "Level \(level)" }

    var content: Element {
        VStack {
            SectionTitle("PUSHED PAGE")

            Label("Level \(level)")
                .fontSize(32)
                .fontAttributes(.bold)
                .horizontalTextAlignment(.center)

            Label("This page and the one under it are two pages, not one shown twice: "
                + "identity on a stack is the DEPTH together with the route, so a stack "
                + "may legally hold the same route more than once.")
                .fontSize(13)
                .textColor(Palette.subtle)
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
                .backgroundColor(Palette.accent)
                .textColor(.white)
                .cornerRadius(8)
                .padding(20, 10)
                .horizontalOptions(.center)
                .onClicked { path.append(.level(level + 1)) }

            Button("Back")
                .padding(20, 10)
                .horizontalOptions(.center)
                .onClicked { path.removeLast() }

            Label("`path.append(...)` and `path.removeLast()` - and the platform's own "
                + "back arrow, its swipe and Android's system gesture do the same thing "
                + "to the same array: the host reports the depth that survived and the "
                + "array is truncated to match. A gesture let go halfway says nothing, "
                + "because nothing happened.")
                .fontSize(12)
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)

            Label("Go deeper and come back: this page counts a departure and a "
                + "SECOND arrival, because it is the same page throughout - "
                + "`onAppearing` runs on every arrival, which is what makes it "
                + "the place to refresh something that may have changed while "
                + "the page was covered. The FIRST arrival of a page a message "
                + "is describing for the very first time is not reported: the "
                + "platform raises it while that message is still being "
                + "applied, and a report from inside an apply is dropped.")
                .fontSize(12)
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)
        }
        .spacing(16)
        .padding(24)
    }
}
