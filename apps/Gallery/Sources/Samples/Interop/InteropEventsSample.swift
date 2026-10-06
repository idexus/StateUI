#if APPKIT || UIKIT || GTK || WINUI || ANDROID || WEB
import StateUI

/// Events the host raises on its own, heard with no control behind them.
struct InteropEventsSample: SampleContent, ExampleContent {
    // listing: InteropEventsSample
    @State private var battery = "not heard yet"
    @State private var log: [String] = []
    @State private var heard: [HostEventSubscription] = []
    // listing: end

    static let id = InteropHost.key + "Events"
    static let title = "Hearing from " + InteropHost.name
    static let summary = "Events the host raises on its own, heard with no control behind them."

    static var code: String { Listings.joined("GalleryContract", "InteropEventsSample") }

    static let codeHeading = "In StateUI"

    #if APPKIT
    static let hostCode = HostCode(in: InteropHost.name, marked: "InteropEventsSample.AppKit.swift")
    #elseif UIKIT
    static let hostCode = HostCode(in: InteropHost.name, marked: "InteropEventsSample.UIKit.swift")
    #elseif GTK
    static let hostCode = HostCode(in: InteropHost.name, marked: "InteropEventsSample.GTK.swift")
    #elseif WINUI
    static let hostCode = HostCode(in: InteropHost.name, marked: "InteropEventsSample.WinUI.swift", "InteropEventsSample.WinUI.cpp")
    #elseif WEB
    static let hostCode = HostCode(in: InteropHost.name, marked: "InteropEventsSample.Web.swift", "InteropEventsSample.Web.javascript")
    #else
    static let hostCode = HostCode(in: InteropHost.name, marked: "InteropEventsSample.Android.swift", "InteropEventsSample.Android.java")
    #endif

    var body: some View {
        VStack {
            DebugInfoLabel()

            Text("battery: \(battery)")
                .fontSize(17)

            Text(log.isEmpty
                ? "Plug or unplug the power."
                : log.suffix(4).joined(separator: "\n"))
                .fontSize(13)
                .textColor(Palette.subtle)
        }
        .spacing(8)
        .onCreated {
            heard.forEach { $0.cancel() }
            heard = [
                HostEvents.on(GalleryContract.batteryChanged) { level, charging in
                    battery = "\(Int((level * 100).rounded()))%" + (charging ? ", charging" : "")
                    log.append("\(log.count + 1). battery: \(battery)")
                },
            ]
        }
        .onDestroying {
            heard.forEach { $0.cancel() }
            heard = []
        }
    }

    var notes: (any View)? {
        VStack {
            Text("The host calls `StateUIEvents.raise(event, values)` when the platform "
                + "reports something, from any thread. Every `HostEvents.on` subscription "
                + "to that member runs like a control's handler: on the library's "
                + "executor, handed the values the contract declares, free to await and to "
                + "write `@State`. The head declares each event it raises with "
                + "`StateUIEvents.raises`, so a handler listening for one nothing raises "
                + "is told so once.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("The subscriptions are made in `.onCreated` and cancelled in "
                + "`.onDestroying`, so the page listens while it is in the tree. A raise "
                + "nobody hears is an ordinary answer, so the host wires its sources "
                + "unconditionally.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("A desktop with no battery reports nothing at all, and that is the "
                + "honest answer rather than a failure: this page then keeps saying it "
                + "has not heard.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
#endif
