#if APPKIT || UIKIT || GTK || WINUI || ANDROID || WEB
import StateUI

/// A control the application registers with its host, described here like any
/// other.
struct InteropControlSample: SampleContent, ExampleContent {
    // listing: InteropControlSample
    @State private var signal = TrafficSignal.stop
    // listing: end

    static let id = InteropHost.key + "Control"
    static let title = InteropHost.control
    static let summary = InteropHost.controlSummary

    static let codeHeading = "In StateUI"

    static var code: String { Listings.joined("TrafficLight", "InteropControlSample") }

    #if APPKIT
    static let hostCode = HostCode(in: InteropHost.name, marked: "InteropControlSample.AppKit.swift", "InteropControlSample.AppKit.list.swift")
    #elseif UIKIT
    static let hostCode = HostCode(in: InteropHost.name, marked: "InteropControlSample.UIKit.swift", "InteropControlSample.UIKit.list.swift")
    #elseif GTK
    static let hostCode = HostCode(in: InteropHost.name, marked: "InteropControlSample.GTK.swift")
    #elseif WINUI
    static let hostCode = HostCode(in: InteropHost.name, marked: "InteropControlSample.WinUI.swift", "InteropControlSample.WinUI.cpp")
    #elseif WEB
    static let hostCode = HostCode(in: InteropHost.name, marked: "InteropControlSample.Web.swift", "InteropControlSample.Web.javascript")
    #else
    static let hostCode = HostCode(in: InteropHost.name, marked: "InteropControlSample.Android.swift", "InteropControlSample.Android.controls.swift", "InteropControlSample.Android.java", "InteropControlSample.Android.natives.java")
    #endif

    var body: some View {
        VStack {
            DebugInfoLabel()

            TrafficLight()
                .signal(signal)
                .onLampTapped { index in
                    signal = TrafficSignal(rawValue: Int32(index)) ?? signal
                }
                .horizontalAlignment(.center)

            Text("signal: \(signal)")
                .fontSize(17)
                .horizontalTextAlignment(.center)

            Button("Advance")
                .onClicked {
                    let all = TrafficSignal.allCases
                    signal = all[(all.firstIndex(of: signal)! + 1) % all.count]
                }
        }
        .spacing(8)
    }

    var notes: (any View)? {
        VStack {
            Text(InteropHost.lamps + " The host creates it once, keeps "
                + "it by identity between renders, puts each described value on it, and "
                + "then applies what every view shares - margins, alignment, opacity, "
                + "gestures.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("The control never switches itself. A tap raises `lampTapped` through "
                + "the reports its `create` is handed, this sample's `@State` decides, "
                + "and the next render lights the lamp.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("`TrafficSignal` is a closed vocabulary, so it crosses as its member's "
                + "number - and the registration is handed it back as `TrafficSignal`, "
                + "typed, rather than as that number.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
#endif
