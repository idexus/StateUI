import StateUI

// listing: ModalPage
/// A page presented OVER everything - the bars, the menu and the stack alike.
///
/// A sheet has no bar of its own, so it carries its own way out; a stack
/// presented in a sheet brings its bar. Each sheet stands on the button
/// presenting it, by a state of its own.
struct ModalPage: View {
    /// Whether this page stands presented: Close writes it false.
    @Binding var shown: Bool

    /// How many sheets stand, this one included.
    let depth: Int

    /// Whether another page stands over this one, and whether a stack does.
    @State private var presentsAnother = false
    @State private var presentsStack = false

    /// What the field says, and which of the two words the arrows mark.
    @State private var query = ""
    @State private var mark = 0

    var body: some View {
        VStack {
            SectionTitle("Over everything")

            Text("Native modal page")
                .fontSize(20)
                .fontWeight(.bold)
                .horizontalTextAlignment(.center)

            Text("Present a stack: its bar comes with it.")
                .fontSize(13)
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)

            // The field holds the keyboard in the sheet; the stack holding it takes the arrows.
            VStack {
                TextField($query)
                    .placeholder("Type here: Up and Down move the mark")

                Text(mark == 0 ? "▸ One    Two" : "One    ▸ Two")
                    .fontSize(13)
                    .horizontalTextAlignment(.center)
            }
            .spacing(6)
            .onKeyPressed([.upArrow, .downArrow]) { press in mark = press.key == .upArrow ? 0 : 1 }

            Button("Close")
                .horizontalAlignment(.center)
                .onClicked { shown = false }

            Button("Present another")
                .horizontalAlignment(.center)
                .onClicked { presentsAnother = true }
                .sheet(isPresented: $presentsAnother) {
                    ModalPage(shown: $presentsAnother, depth: depth + 1)
                }

            Button("Present a stack")
                .horizontalAlignment(.center)
                .onClicked { presentsStack = true }
                .sheet(isPresented: $presentsStack) {
                    StackSheet(shown: $presentsStack)
                }

            Text("Depth: \(depth)")
                .fontSize(12)
                .fontFamily("Menlo")
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)
        }
        .spacing(16)
        .padding(24)
        .verticalAlignment(.center)
    }
}

/// A stack presented in a sheet: the bar over its pages is the stack's own, its close button the page's to offer.
struct StackSheet: View {
    @Binding var shown: Bool
    @State private var path: [Int] = []
    @State private var offersClose = true

    var body: some View {
        NavigationStack($path) {
            VStack {
                Switch("Close button", isOn: $offersClose)
                Button("Push").onClicked { path.append(path.count + 1) }
                Button("Close").onClicked { shown = false }
            }
            .spacing(16)
            .padding(24)
            .galleryPage("In a stack")
            .showsCloseButton(offersClose)
        } destination: { number in
            Text("Page \(number)")
                .padding(24)
                .galleryPage("Pushed")
        }
    }
}
// listing: end
