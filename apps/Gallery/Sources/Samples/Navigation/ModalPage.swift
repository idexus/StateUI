import StateUI

/// A page presented OVER everything - the bars, the menu and the stack alike.
///
/// It carries its own way out because the modal presentation covers the page
/// that opened it.
struct ModalPage: ContentView {
    /// Where the gallery is. A modal closes itself by shortening the array it
    /// is a member of, exactly as a pushed page pops itself.
    let nav: Navigation

    /// The page itself.
    @Environment private var page: PageSession

    var content: any View {
        VStack {
            SectionTitle("Over everything")

            Label("Native modal page")
                .fontSize(20)
                .fontAttributes(.bold)
                .horizontalTextAlignment(.center)

            Label("The host chooses the presentation that belongs to this platform.")
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

            Button("Present another")
                .padding(20, 10)
                .horizontalOptions(.center)
                .onClicked { nav.present(.page) }

            Label("Depth: \(nav.sheets.count)")
                .fontSize(12)
                .fontFamily("Menlo")
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)
        }
        .spacing(16)
        .padding(24)
        .verticalOptions(.center)
        .onCreated {
            page.title = "Presented"
            page.backgroundColor = Palette.surface
        }
    }
}
