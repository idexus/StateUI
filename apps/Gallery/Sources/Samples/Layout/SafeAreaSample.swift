import StateUI

/// A page whose rows scroll under what stands over it - its stack's bar, a phone's status bar and home indicator - or
/// stand clear of it.
struct SafeAreaSample: SampleContent, ExampleContent {
    // listing: SafeAreaSample
    @State private var presented = false
    @State private var under = true
    @State private var path: [Int] = []
    // listing: end

    static let id = "safeArea"
    static let title = "Safe area"
    static let summary = "What stands over a page - its bars, a notch, the home indicator - and content running under it."

    // listing: SafeAreaSample
    var body: some View {
        Button("Open a page")
            .onClicked { presented = true }
            .sheet(isPresented: $presented) {
                NavigationStack($path) {
                    Grid {
                        ScrollView {
                            VStack {
                                Switch($under).text("Under the bars")
                                ForEach(Array(1...40), id: \.self) { row in
                                    Text("Row \(row)")
                                }
                            }
                            .spacing(14)
                            .padding(20)
                        }
                    }
                    .ignoresSafeArea(under ? .all : .none)
                    .galleryPage("Safe area")
                } destination: { _ in
                    Text("")
                }
            }
    }
    // listing: end

    var notes: (any View)? {
        Text("Open the page and scroll: its rows pass under the bars, or stop at them with the switch off.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
