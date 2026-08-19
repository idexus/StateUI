import StateUI

/// A page in a WINDOW of its own - see `MultiWindowSample`.
///
/// Not a `GalleryPage`: those carry a way home in the corner of a bar, and this
/// page is the whole of its window. What it carries instead is its own way out,
/// which closes the window by taking its number out of the application's list.
///
/// The interesting part is the READOUT. This page is built from the same tree,
/// by the same renderer, out of the same `@State` as the main window - so
/// walking around over there changes what is written here, with nothing
/// subscribed and nothing sent between the two. There is one Swift application;
/// windows are how much of it is on screen.
struct InspectorPage: ContentPage {
    /// Which inspector this is. Its identity as well as its name: the window is
    /// written `.id(number)`, so this page and this window belong to each other
    /// however the list is reordered.
    let number: Int

    /// Where the gallery is, borrowed the way every page borrows it.
    let nav: Navigation

    /// The APPLICATION's phase - one value per process, moved by whichever
    /// window reported last. Read here to show exactly that: what it says
    /// depends on what the platform did with the OTHER window, which is
    /// precisely what a per-window value could not express.
    @Environment var window: WindowInfo

    var title: String? { "Inspector \(number)" }
    var backgroundColor: Color? { Palette.surface }

    var content: Element {
        ScrollView {
            VStack {
                Label("Inspector \(number)")
                    .fontSize(22)
                    .fontAttributes(.bold)

                Label("A window of its own, from the same tree.")
                    .fontSize(13)
                    .textColor(Palette.subtle)

                SectionTitle("WHERE THE GALLERY IS")

                Reading(name: "section", value: "\(nav.section)")
                Reading(name: "path", value: nav.path.isEmpty
                    ? "empty"
                    : nav.path.map { "\($0)" }.joined(separator: " › "))
                Reading(name: "menu", value: nav.menuOpen ? "open" : "closed")
                Reading(name: "sheets", value: "\(nav.sheets.count)")
                Reading(name: "windows", value:
                    "1 + \(nav.inspectors.count) + \(nav.documents.count)")
                Reading(name: "phase", value: "\(window.phase)")

                Label("The phase is the APPLICATION's, not this window's - one value a "
                    + "process moves as any of its windows comes and goes. What it says "
                    + "here depends on what the platform did with the OTHER window: "
                    + "`activated` where both are on screen at once, which is a Mac and "
                    + "an iPad up to iPadOS 18, and `stopped` on iPadOS 26, which shows "
                    + "this window full screen and puts the main one away. One value "
                    + "either way - that is what tells it apart from a per-window "
                    + "reading, and the six handlers on a Window are the per-window half.")
                    .fontSize(12)
                    .textColor(Palette.subtle)

                Label("Move around in the main window and watch these change. Nothing "
                    + "here is subscribed to anything: both windows are built from one "
                    + "`@State`, in one render, and the message that carries the change "
                    + "names both of them.")
                    .fontSize(12)
                    .textColor(Palette.subtle)

                SectionTitle("AND THE WAY OUT")

                Button("Close this window")
                    .backgroundColor(Palette.accent)
                    .textColor(.white)
                    .cornerRadius(8)
                    .padding(20, 10)
                    .horizontalOptions(.center)
                    .onClicked { nav.closeInspector(number) }

                Label("`inspectors.removeAll { $0 == \(number) }` - and the host closes "
                    + "the window because the tree stopped describing it. The platform's "
                    + "own close button is the same move from the other end: it reports "
                    + "`destroying`, and the handler on the window runs this very line.")
                    .fontSize(12)
                    .textColor(Palette.subtle)
            }
            .spacing(12)
            .padding(20)
        }
    }
}

/// One line of the readout: a name and what it says right now.
private struct Reading: ContentView {
    let name: String
    let value: String

    var content: Element {
        HStack {
            Label(name)
                .fontSize(13)
                .textColor(Palette.subtle)
                .widthRequest(80)

            Label(value)
                .fontSize(13)
                .fontFamily("Menlo")
                .textColor(Palette.accent)
        }
        .spacing(8)
    }
}
