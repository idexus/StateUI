#if APPKIT || UIKIT || ANDROID || WINUI || GTK || WEB
import StateUI

/// Events the host raises on its own, heard with no control behind them.
struct InteropEventsSample: SampleContent, ExampleContent {
    // listing: InteropEventsSample
    @State private var battery = "not heard yet"
    @State private var log: [String] = []
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

    // listing: InteropEventsSample
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
        // Heard while the page stands: subscribed as it is made, cancelled as it leaves.
        .onHostEvent(GalleryContract.batteryChanged) { level, charging in
            battery = "\(Int((level * 100).rounded()))%" + (charging ? ", charging" : "")
            log.append("\(log.count + 1). battery: \(battery)")
        }
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("The host calls `StateUIEvents.raise(event, values)`, from any thread, "
                + "when the platform reports something. Every `.onHostEvent` - and every "
                + "`HostEvents.on` subscription - hears it in a job of the UI thread's, like a control's handler: on "
                + "`MainActor`, free to write `@State`, and to await through a `gate:`. "
                + "The head declares each event it raises with `StateUIEvents.raises`, so "
                + "a handler listening for one nothing raises is told so once.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("`.onHostEvent` belongs to the page: it listens while the page is in the "
                + "tree, and nothing is cancelled by hand. A raise nobody hears is an "
                + "ordinary answer, so the host wires its sources unconditionally.")
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
