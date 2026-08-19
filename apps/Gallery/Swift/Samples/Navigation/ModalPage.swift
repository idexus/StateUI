import StateUI

/// A page presented OVER everything - the bars, the menu and the stack alike.
///
/// Not a `GalleryPage`: those carry a way home in the corner of a bar, and a
/// modal page has no bar at all. What it carries instead is its own way out,
/// which every modal page has to - there is nothing behind it to press.
struct ModalPage: ContentPage {
    /// Where the gallery is. A modal closes itself by shortening the array it
    /// is a member of, exactly as a pushed page pops itself.
    let nav: Navigation

    /// How UIKit is asked to draw it. Ignored off Apple, where a modal page is
    /// always the whole window.
    let style: UIModalPresentationStyle

    var title: String? { "Presented" }
    var backgroundColor: Color? { Palette.surface }

    /// The page's OWN property, which is why it can be answered here: a sheet
    /// knows what it looks like wherever it is presented from.
    var modalPresentationStyle: UIModalPresentationStyle? { style }

    var content: Element {
        VStack {
            SectionTitle("OVER EVERYTHING")

            Label("This page is on the window's modal stack.")
                .fontSize(20)
                .fontAttributes(.bold)
                .horizontalTextAlignment(.center)

            Label("`.\(style)`")
                .fontSize(15)
                .fontFamily("Menlo")
                .textColor(Palette.accent)
                .horizontalTextAlignment(.center)

            Label("Look at what is covered: the navigation bar has gone, and the way "
                + "back with it. That is what makes a modal a modal - it is not on any "
                + "stack and not in any tab, it is over the window. Which is why this "
                + "page carries its own way out.")
                .fontSize(13)
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)

            Button("Close")
                .backgroundColor(Palette.accent)
                .textColor(.white)
                .cornerRadius(8)
                .padding(20, 10)
                .horizontalOptions(.center)
                .onClicked { nav.dismiss() }

            Button("And one over this one")
                .padding(20, 10)
                .horizontalOptions(.center)
                .onClicked { nav.present(.card) }

            Label("`sheets.append(...)` from a sheet presents over the sheet: the modal "
                + "stack is a stack because the platforms make it one. Closing is "
                + "`removeLast()`, and dragging an iOS card down does the same thing to "
                + "the same array - the host reports how many SURVIVED.")
                .fontSize(12)
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)
        }
        .spacing(16)
        .padding(24)
        .verticalOptions(.center)
    }
}
