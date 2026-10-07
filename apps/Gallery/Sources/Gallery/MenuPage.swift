// The menu that slides in from the side.

import StateUI

// listing: MenuPage
/// The gallery's sidebar - and it is an ordinary page.
///
/// That is the whole point of it. A view with the mark at the top,
/// some rows in the middle and a line at the bottom - and a row is a view with
/// a tap on it that writes state. There is no menu vocabulary to learn: what
/// can go in the pane is whatever can go on a page, and what a row does is
/// whatever a handler can do.
///
/// Its title names the pane on hosts whose navigation chrome exposes that name.
struct MenuPage: View {
    /// Everything the gallery shows - the rows are one per group.
    let catalog: Catalog

    /// Where the gallery is, so a row can move it and know whether it is the
    /// row the user is on.
    let nav: Navigation

    /// What the window has said about its life - written by the
    /// `WindowPhaseLog` this page holds, as the window's phase moves.
    let log: WindowLog

    /// Whether the row that is hidden by default is listed - the Split view sample
    /// writes it, and here it is an `if` around the row.
    let listsHiddenRow: Bool

    /// The device's facts: which samples Surprise me draws from, and the line
    /// at the bottom.
    @Environment(\.device) private var device

    var body: some View {
        Grid {
            header

            ScrollView {
                rows
            }
            .gridRow(1)

            footer

            WindowPhaseLog(log: log)
        }
        // Three rows: the header and the footer keep their height, and the
        // rows take what is left and scroll between them.
        .rows(.auto, .fill, .auto)
        .title("StateUI")
        // The picture on the button that opens the menu, where the host draws
        // that button from this page.
        .icon(ImageSource(light: "nav_menu.png", dark: "nav_menu_dark.png"))
    }

    /// The mark and the name, on the pane the platform draws: the gradient
    /// is the home page's alone.
    private var header: some View {
        HStack {
            Image(ImageSource(light: "stateui_mark_violet.png", dark: "stateui_mark_violet_dark.png"))
                .width(28)
                .height(28)
                .verticalAlignment(.center)

            Text("StateUI")
                .fontSize(20)
                .fontAttributes(.bold)
                .tracking(-0.3)
                .verticalAlignment(.center)
        }
        .spacing(10)
        .padding(left: 20, top: 12, right: 20, bottom: 8)   // listing: keep
    }

    /// Home, one row per group, the row that is not always listed, and the one
    /// row that goes nowhere fixed: it opens a sample chosen at random.
    private var rows: some View {
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
            // is reachable either way - `.hidden` is a value, and a value nobody
            // drew a row for is still a value. The list being a view, the answer
            // is an `if`.
            if listsHiddenRow {
                MenuRow("Not in the list") { nav.open(.hidden) }
                    .icon(ImageSource(light: "nav_hidden.png", dark: "nav_hidden_dark.png"))
                    .chosen(nav.showing(.hidden))
            }

            // A row with no fixed place to go: it pushes a sample chosen at
            // random. It needs no type of its own: the same view, with a
            // different handler.
            MenuRow("Surprise me") { nav.surprise(from: catalog, on: device.info.formFactor) }
                .icon(ImageSource(light: "nav_surprise.png", dark: "nav_surprise_dark.png"))
        }
        // Clear of the pane's edges, so the chosen row's fill stands inside it.
        .padding(horizontal: 10, vertical: 8)
    }

    /// What is underneath: the platform compiled in, the formFactor the host
    /// answered before the first render, and the StateUI release it is built on.
    private var footer: some View {
        Text("native: \(stateUIPlatform()) · \(device.info.formFactor)\nStateUI \(stateUIVersion())")
            .fontSize(11)
            .textColor(Palette.subtle)
            .horizontalTextAlignment(.center)
            .padding(12)   // listing: keep
            // The footer's own row, written on the footer.
            .gridRow(2)
    }
}
// listing: end
