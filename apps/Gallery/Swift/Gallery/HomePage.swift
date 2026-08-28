// Where the gallery opens.

import StateUI

/// What this is, and every group there is.
///
/// The one page that names the whole catalog, so a reader who has never seen the
/// library can find the control they came for without opening the flyout.
struct HomePage: GalleryPage {
    let catalog: Catalog

    /// Where the gallery is - a card switches the section.
    let nav: Navigation

    /// The device's facts, resolved from the standard environment - the
    /// idiom for the count, and the footer's word.
    @Environment var device: DeviceInfo

    var title: String? { "Home" }

    /// No home button: this is it. The bar and everything else about the page is
    /// the house style, which is why this is the one thing overridden.
    var toolbarItems: [ToolbarItem] { [] }

    var content: Element {
        ScrollView {
            VStack {

                // The mark, the name and what it is, on the identity gradient -
                // the one place in the app that says all three at once.
                //
                // The panel paints its own background and its own edge: the
                // implicit Border style fills a card and draws a hairline, and
                // both would show through the gradient.
                Border {
                    VStack {
                        Image("stateui_mark.png")
                            .widthRequest(84)
                            .heightRequest(84)
                            .horizontalOptions(.start)

                        Label("StateUI Gallery")
                            .fontSize(34)
                            .fontAttributes(.bold)
                            .characterSpacing(-0.5)
                            .textColor(Palette.onBrand)

                        Label("MAUI interfaces, written in Swift")
                            .fontSize(15)
                            .textColor(Palette.onBrand)
                            .opacity(0.85)
                    }
                    .spacing(10)
                    .padding(22)
                }
                .background(Palette.identity)
                .stroke(.transparent)
                .strokeThickness(0)
                .strokeShape(.roundRectangle(18))

                Label("Every example below is described in Swift and rendered as real "
                    + "MAUI controls.")
                    .fontSize(15)
                    .textColor(Palette.subtle)

                // The platform is compiled in; the idiom - phone, tablet,
                // desktop - is the host's answer, which is what lets the
                // catalog list desktop chrome only where it draws.
                Label("native: \(stateUIPlatform()) · \(device.idiom)")
                    .fontSize(11)
                    .textColor(Palette.subtle)

                SectionTitle("\(catalog.sampleCount(on: device.idiom)) SAMPLES "
                    + "IN \(catalog.groups.count) GROUPS")

                // One card per group. Tapping PUSHES that group onto this page,
                // which is what the row's chevron promises and what makes the
                // back button lead home from anywhere in the gallery.
                ForEach(catalog.groups, id: \.route) { group in
                    Card(group.title, summary: group.summary) {
                        nav.push(.group(group.route))
                    }
                    .icon(group.icon)
                }
            }
            .spacing(14)
            .padding(24)
        }
    }
}
