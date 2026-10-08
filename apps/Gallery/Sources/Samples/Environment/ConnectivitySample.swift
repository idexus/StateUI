import StateUI

/// Whether the internet is reachable, and by what.
struct ConnectivitySample: SampleContent, ExampleContent {
    // listing: ConnectivitySample
    /// The network, as the host last reported it.
    @Environment(\.device) var device
    // listing: end

    static let id = "connectivity"
    static let title = "Connectivity"
    static let summary = "Whether the internet is reachable and by what - "
        + "updated the moment it changes."

    // listing: ConnectivitySample
    var body: some View {
        // The list is the host's answer as given, and a host may report one
        // entry per adapter, so repeats are collapsed for display and the
        // value stays untouched. Sorted, because a Set's own order changes
        // run to run.
        let profiles = Set(device.connectivity.connectionProfiles.map { "\($0)" })
            .sorted()
            .joined(separator: ", ")

        return VStack {
            // The connection is read here, so a change to it builds this
            // closure.
            DebugInfoLabel()

            Text(device.connectivity.networkAccess == .internet ? "online" : "offline")
                .fontSize(34)
                .fontAttributes(.bold)
                .horizontalTextAlignment(.center)

            Text("access · \(device.connectivity.networkAccess)")
                .fontSize(15)
            Text("via · \(profiles.isEmpty ? "nothing reported" : profiles)")
                .fontSize(15)

            Button("Save to the cloud")
                .isEnabled(device.connectivity.networkAccess == .internet)
                .horizontalAlignment(.center)
        }
        .spacing(10)
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("The button above is enabled by a READ - "
                + "`device.connectivity.networkAccess == .internet` - so it follows the "
                + "network with no handler anywhere. On a phone, turn airplane "
                + "mode on and off and watch this page follow; on Android, "
                + "`adb shell svc wifi disable` takes the Wi-Fi away.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("A desktop wired to Ethernet may never CHANGE, but the "
                + "values here are still the host's answer. A host that "
                + "cannot observe reachability reports `.unknown` and no "
                + "profiles.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(10)
    }
}
