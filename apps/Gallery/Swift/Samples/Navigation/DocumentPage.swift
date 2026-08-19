import StateUI

/// A window the READER asked their platform for - see `MultiWindowSample`.
///
/// The whole difference from `InspectorPage` beside it is who asked. An
/// inspector is opened by a button in the interface; this one by *File ▸ New
/// Window* on a Mac or the window controls on an iPad - a gesture the
/// application does not draw and cannot intercept. What reaches
/// the tree is `onCreatingWindow` on the Application, and the gallery answers
/// it with `documents.append(…)`: one more entry in `windows`, and the window
/// the platform already opened is the one this page appears in.
///
/// Which is the point worth reading twice. There is no separate "system window"
/// path through the library - the platform's request and a button press end in
/// the same append, so a document opened either way is the same window
/// described the same way.
struct DocumentPage: ContentPage {
    /// Which document this is. Its identity as well as its name: the window
    /// carries `.id(number)`, so this page and this window stay together
    /// however the list is reordered.
    let number: Int

    /// Where the gallery is, borrowed the way every page borrows it.
    let nav: Navigation

    var title: String? { "Document \(number)" }
    var backgroundColor: Color? { Palette.surface }

    /// EDGE TO EDGE, the top of this page being the banner - the same reason
    /// `MenuPage` says it, and the same measurement behind it: without it the
    /// page's own colour shows above the picture in a strip.
    var useSafeArea: Bool? { false }

    var content: Element {
        Grid {
            banner

            ScrollView {
                body
            }
            .gridRow(1)
        }
        .rowDefinitions(.auto, .star)
        .safeAreaEdges(.none)
    }

    /// The banner: what this window is, said by the window itself.
    private var banner: Element {
        VStack {
            Label("OPENED BY THE SYSTEM")
                .fontSize(11)
                .fontAttributes(.bold)
                .characterSpacing(1.5)
                .textColor(Palette.onBrand)
                .opacity(0.85)

            Label("Document \(number)")
                .fontSize(26)
                .fontAttributes(.bold)
                .characterSpacing(-0.5)
                .textColor(Palette.onBrand)

            Label("You asked your platform for a window. This is the application "
                + "answering with one.")
                .fontSize(13)
                .textColor(Palette.onBrand)
                .opacity(0.85)
        }
        .spacing(6)
        .safeAreaEdges(.none)
        .padding(24, 40, 24, 26)
        .background(Palette.identity)
    }

    /// How it got here, that it is the same tree as every other window, and the
    /// way out.
    private var body: Element {
        VStack {
            SectionTitle("HOW THIS WINDOW HAPPENED")

            Label("The platform opened a window and told the tree about it. Nothing "
                + "in the gallery drew the gesture that did it - there is no menu "
                + "item here for `File ▸ New Window`, and on an iPad the control "
                + "belongs to the system. What the application supplies is an "
                + "ANSWER, and the answer is one line of ordinary state.")
                .fontSize(13)
                .textColor(Palette.subtle)

            CodeBlock("""
                var onCreatingWindow: EventHandler? {       // MAUI: Application.CreateWindow
                    { documents.append((documents.max() ?? 0) + 1) }
                }
                """).title("")

            Label("An application that writes nothing there shows the windows it "
                + "lists, and the platform's window is closed again - which is the "
                + "honest answer to a request nothing describes, and better than a "
                + "window left blank.")
                .fontSize(12)
                .textColor(Palette.subtle)

            SectionTitle("AND IT IS THE SAME GALLERY")

            DocumentReading(name: "section", value: "\(nav.section)")
            DocumentReading(name: "path", value: nav.path.isEmpty
                ? "empty"
                : nav.path.map { "\($0)" }.joined(separator: " › "))
            DocumentReading(name: "documents", value: nav.documents.isEmpty
                ? "none"
                : nav.documents.map(String.init).joined(separator: ", "))
            DocumentReading(name: "windows", value:
                "1 + \(nav.inspectors.count) + \(nav.documents.count)")

            Label("Read live from the same `@State` the main window is built from, "
                + "which is what tells you this is one application and not a second "
                + "copy of it: walk around over there and these change here. A "
                + "document with state of ITS OWN would put that state in the "
                + "array - `documents` would hold a value per document rather than "
                + "a number - and nothing else about this would move.")
                .fontSize(12)
                .textColor(Palette.subtle)

            SectionTitle("THE WAY OUT")

            Button("Close this window")
                .backgroundColor(Palette.accent)
                .textColor(.white)
                .cornerRadius(8)
                .padding(20, 10)
                .horizontalOptions(.center)
                .onClicked { nav.closeDocument(number) }

            Label("`documents.removeAll { $0 == \(number) }`, and the host closes the "
                + "window because the tree stopped describing it. The platform's own "
                + "close button is the same move from the other end: it reports "
                + "`destroying`, and the handler on the window runs this very line.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Button("Close every window but the main one")
                .padding(20, 10)
                .horizontalOptions(.center)
                .onClicked { nav.closeExtraWindows() }

            Label("`inspectors = []` and `documents = []` - closing many windows is "
                + "describing none of them, so it is the same move as closing one. It is "
                + "here rather than only in the sample because this is the window you are "
                + "looking at when there are more of these than you meant: a Mac restores "
                + "the scenes an app ended with, so a session that finished with dozens "
                + "open starts with dozens open, and closing them THROUGH THE TREE is what "
                + "takes them off the platform's list.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
        .padding(24)
    }
}

/// One line of the readout: a name and what it says right now.
///
/// Not `private`, and not shared with the twin in InspectorPage either: at file
/// scope `private` means fileprivate, so a type used from one file lives in
/// that file - and these two pages are read side by side, where a single shared
/// row type would make the difference between them harder to see, not easier.
struct DocumentReading: ContentView {
    let name: String
    let value: String

    var content: Element {
        HStack {
            Label(name)
                .fontSize(13)
                .textColor(Palette.subtle)
                .widthRequest(100)

            Label(value)
                .fontSize(13)
                .fontFamily("Menlo")
                .textColor(Palette.accent)
        }
        .spacing(8)
    }
}
