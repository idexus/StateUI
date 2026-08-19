// The menu that slides in from the side.

import StateUI

/// The gallery's flyout - and it is an ordinary page.
///
/// That is the whole point of it. A Shell's flyout is a list the library
/// describes: items with routes, a template run over them, a header slot, a
/// footer slot, a selection MAUI decides and a `MenuItem` type for a row that
/// merely does something. None of that exists here. This is a `ContentPage` with
/// a gradient at the top, some rows in the middle and a line at the bottom, and
/// a row is a view with a tap on it that writes state.
///
/// It has to have a TITLE: MAUI refuses a flyout page without one - the platform
/// draws it where the pane's own name goes - and the host reports that rather
/// than letting the assignment throw. See Views/FlyoutPage.swift.
struct MenuPage: ContentPage {
    /// Everything the gallery shows - the rows are one per group.
    let catalog: Catalog

    /// Where the gallery is, so a row can move it and know whether it is the
    /// row the reader is on.
    let nav: Navigation

    /// Whether the row that is hidden by default is listed - the Flyout sample
    /// writes it, and here it is an `if`. In a Shell this is
    /// `flyoutItemIsVisible` on an item the library holds.
    let listsHiddenRow: Bool

    /// Opens a sample nobody asked for. Handed down rather than built here: the
    /// title bar's chip does the same thing, and one of them has to be the copy.
    let surprise: EventHandler

    /// The device's facts, for the line at the bottom.
    @Environment private var device: DeviceInfo

    var title: String? { "StateUI" }

    /// The picture MAUI's own flyout toggle wears. Without it Apple draws the
    /// flyout page's TITLE as the button - the word "StateUI" where Android
    /// shows three bars - because that is what a `FlyoutPage` falls back to.
    /// MAUI: Page.IconImageSource, read here by the arrangement rather than by
    /// this page.
    var iconImageSource: ImageSource? { "nav_menu_dark.png" }

    var backgroundColor: Color? { Palette.surface }

    /// EDGE TO EDGE, because the top of this page is a PICTURE. Without it the
    /// page's own colour shows above the banner in a strip - measured on Mac
    /// Catalyst, where the window's title bar is what the page insets itself
    /// below, and the strip was black in the dark theme. The layouts inside say
    /// `.safeAreaEdges(.none)` too, and that is not the same question: a layout
    /// can only give away room the PAGE handed it.
    var useSafeArea: Bool? { false }

    var content: Element {
        Grid {
            header

            ScrollView {
                rows
            }
            .gridRow(1)

            footer
        }
        // Three rows: the header and the footer keep their height, the rows
        // take what is left and scroll between them - which is where a Shell
        // puts slots of its own.
        //
        // The header is OUTSIDE the scroller, and that is not only taste. On
        // iOS a scroller insets its own content below the status bar and there
        // is no MAUI property to say otherwise - `SafeAreaEdges` belongs to a
        // Layout, and a ScrollView is not one - so a gradient inside it began
        // 20 points down, with the page's own colour above it: measured on an
        // iPhone SE simulator, and it read as the header being cut off. A
        // direct child of this Grid takes the top edge instead.
        .rowDefinitions(.auto, .star, .auto)
        // EDGE TO EDGE, so the gradient runs behind the status bar the way the
        // navigation bar beside it does. Every LAYOUT insets itself, so the
        // header says it too.
        .safeAreaEdges(.none)
    }

    /// The mark, the name and what this is - on the gradient the home page opens
    /// with, so the menu and the page behind it are plainly one application.
    private var header: Element {
        VStack {
            Image("stateui_mark.png")
                .widthRequest(51)
                .heightRequest(51)
                .horizontalOptions(.start)

            Label("StateUI")
                .fontSize(24)
                .fontAttributes(.bold)
                .characterSpacing(-0.5)
                .textColor(Palette.onBrand)

            Label("MAUI interfaces, written in Swift")
                .fontSize(12)
                .textColor(Palette.onBrand)
                .opacity(0.85)
        }
        .spacing(6)
        // Edge to edge, and padded down by hand. An iOS layout insets its
        // children below the status bar at ARRANGE time while its MEASURED
        // height knows nothing of it - so a header left to the platform kept its
        // content-sized frame and had its bottom clipped by exactly the inset
        // (measured on an iPhone 15 Pro simulator: 59 points, the tagline gone
        // and the name cut mid-letter). The gradient was always meant to run
        // behind the status bar anyway.
        .safeAreaEdges(.none)
        .padding(20, 40, 20, 22)
        .background(Palette.identity)
    }

    /// Home, one row per group, the row that is not always listed, and the one
    /// row that performs an act rather than going anywhere.
    private var rows: Element {
        VStack {
            MenuRow("Home") { nav.open(.home) }
                .icon(ImageSource(light: "nav_home.png", dark: "nav_home_dark.png"))
                .chosen(nav.showing(.home))

            // One row per group, built from the catalog - so a new group is a
            // line there rather than a change here.
            ForEach(catalog.groups, id: \.route) { group in
                MenuRow(group.title) { nav.openGroup(group.route) }
                    .icon(group.icon)
                    .chosen(nav.showingGroup(group.route))
            }

            // A row the menu lists only when it is told to. The page behind it
            // is reachable either way - `nav.open(.hidden)` is a value, and a
            // value nobody drew a row for is still a value. In a Shell this is
            // `flyoutItemIsVisible` on an item the library keeps; here the
            // list is a view, so the answer is `if`.
            if listsHiddenRow {
                MenuRow("Not in the list") { nav.open(.hidden) }
                    .icon(ImageSource(light: "nav_hidden.png", dark: "nav_hidden_dark.png"))
                    .chosen(nav.showing(.hidden))
            }

            // A row that DOES something rather than going somewhere - MAUI's
            // MenuItem, which needs a type of its own in a Shell and needs
            // nothing here: it is the same view with a different handler.
            MenuRow("Surprise me", action: surprise)
                .icon(ImageSource(light: "nav_surprise.png", dark: "nav_surprise_dark.png"))
        }
    }

    /// What is underneath: the platform compiled in, and the idiom the host
    /// answered before the first render.
    private var footer: Element {
        Label("native: \(stateUIPlatform()) · \(device.idiom)")
            .fontSize(11)
            .textColor(Palette.subtle)
            .horizontalTextAlignment(.center)
            // Room under it for the home indicator, the content being edge to
            // edge: a phone with no home button draws a bar across the bottom
            // of the screen, and this line would otherwise sit under it.
            .padding(16, 16, 16, 30)
            // Written here rather than at the call site: what comes back from
            // one of these getters is an `Element`, and a placement is a VIEW's
            // property - which is the same reason SamplePage wraps its notes.
            .gridRow(2)
    }
}
