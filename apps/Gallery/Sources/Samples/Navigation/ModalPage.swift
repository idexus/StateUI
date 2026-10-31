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
                Switch($offersClose).text("Close button")
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
