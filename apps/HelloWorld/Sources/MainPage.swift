import StateUI

/// The opening page: a text entry and counter shared by every host.
///
/// A page is a value rebuilt on every render, and the `@State` on it survives
/// that - which is the whole of what makes the counter below work.
struct MainPage: ContentView {
    /// The page as it runs - what it is called, and the rest of what it
    /// says about itself.
    @Environment private var page: PageSession

    @State private var count = 0
    @State private var name = ""

    var content: any View {
        VStack {
            Image("stateui_tile.png")
                .height(120)
                .horizontalAlignment(.center)

            Label(name.isEmpty ? "Hello, StateUI!" : "Hello, \(name)!")
                .fontSize(28)
                .fontAttributes(.bold)
                .horizontalAlignment(.center)

            Entry($name)
                .placeholder("Type your name")
                .maxLength(40)
                .width(240)

            Button(count == 0 ? "Click me" : "Clicked \(count) time\(count == 1 ? "" : "s")")
                .onClicked { count += 1 }
                .horizontalAlignment(.center)
                .margin(20)
        }
        .spacing(16)
        .verticalAlignment(.center)
        .padding(30)
        .onCreated { page.title = "HelloWorld" }
    }
}
