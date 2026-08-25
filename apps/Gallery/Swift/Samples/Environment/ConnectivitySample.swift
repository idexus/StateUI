import StateUI

/// MAUI: Connectivity - whether the internet is reachable, and by what.
struct ConnectivitySample: SampleContent {
    /// The network, as the host last reported it.
    @Environment var connectivity: Connectivity

    static let id = "connectivity"
    static let title = "Connectivity"
    static let summary = "Whether the internet is reachable and by what - "
        + "updated the moment it changes."

    static let code = """
        struct SaveButton: ContentView {
            @Environment var connectivity: Connectivity

            var content: Element {
                VStack {
                    Label(connectivity.networkAccess == .internet
                        ? "online" : "offline · \\(connectivity.networkAccess)")

                    Label("via \\(connectivity.connectionProfiles.map { "\\($0)" }
                        .joined(separator: ", "))")

                    Button("Save to the cloud")
                        .isEnabled(connectivity.networkAccess == .internet)
                }
            }
        }
        """

    var content: Element {
        let profiles = connectivity.connectionProfiles.map { "\($0)" }.joined(separator: ", ")

        return VStack {
            Label(connectivity.networkAccess == .internet ? "online" : "offline")
                .fontSize(34)
                .fontAttributes(.bold)
                .horizontalTextAlignment(.center)

            Label("access · \(connectivity.networkAccess)")
                .fontSize(15)
            Label("via · \(profiles.isEmpty ? "nothing reported" : profiles)")
                .fontSize(15)

            Button("Save to the cloud")
                .isEnabled(connectivity.networkAccess == .internet)
                .backgroundColor(Palette.accent)
                .textColor(.white)
                .cornerRadius(8)
                .padding(20, 10)
                .horizontalOptions(.center)
        }
        .spacing(10)
    }

    var notes: Element? {
        VStack {
            Label("The button above is enabled by a READ - "
                + "connectivity.networkAccess == .internet - so it follows the "
                + "network with no handler anywhere. On a phone, flip airplane "
                + "mode and watch this page change twice; on Android that is "
                + "`adb shell svc wifi disable`, and the manifest declares "
                + "ACCESS_NETWORK_STATE for it.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("A desktop wired to Ethernet may never CHANGE - measured on "
                + "Mac Catalyst - but the values here are still the host's "
                + "answer, pushed before the first render.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(10)
    }
}
