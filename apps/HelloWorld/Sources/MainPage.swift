import StateUI

/// The opening page: a text entry and counter shared by every host.
///
/// A page is a value rebuilt on every render, and the `@State` on it survives
/// that - which is the whole of what makes the counter below work.
struct MainPage: View {
    /// The page as it runs - what it is called, and the rest of what it
    /// says about itself.
    @Environment private var page: PageSession

    @State private var count = 0
    @State private var name = ""

    var body: some View {
        VStack {
            Image("stateui_tile.png")
                .height(120)
                .horizontalAlignment(.center)

            Text(name.isEmpty ? "Hello, StateUI!" : "Hello, \(name)!")
                .fontSize(28)
                .fontAttributes(.bold)
                .horizontalAlignment(.center)

            TextField($name)
                .placeholder("Type your name")
                .maximumLength(40)
                .width(240)

            Button(Self.caption(clicks: count))
                .onClicked { count += 1 }
                .horizontalAlignment(.center)
                .margin(20)
        }
        .spacing(16)
        .verticalAlignment(.center)
        .padding(30)
        .onCreated { page.title = "HelloWorld" }
    }

    /// What the button says once it has been clicked `count` times.
    static func caption(clicks count: Int) -> String {
        count == 0 ? "Click me" : "Clicked \(count) time\(count == 1 ? "" : "s")"
    }
}
