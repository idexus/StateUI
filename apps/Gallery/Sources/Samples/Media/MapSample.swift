import StateUI

/// The platform's own map, with markers, a region to move to, and what it draws.
struct MapSample: SampleContent, ExampleContent {
    // listing: MapSample
    @State private var said = "tap the map, a pin, or its details"

    @Aim(Map.self) private var map
    @State private var kind = MapType.standard
    @State private var traffic = false
    @State private var showsMe = false
    @State private var locked = false
    // listing: end

    static let id = "map"
    static let title = "Map"
    static let summary = "The platform's own map, with pins on it - and the region an act away."

    /// Held still: a map PANS, and the page's scroller would claim the drag -
    /// the rule every gesture sample follows.
    static let scrolls = false

    // listing: MapSample
    var body: some View {
        VStack {
            // What the map last said is read here, so every tap on it builds
            // this closure.
            DebugInfoLabel()

            HStack {
                Button("Old Town")
                    .onClicked(.cancelPrevious) {
                        try await map.moveToRegion(
                            latitude: 50.0617, longitude: 19.9373, radiusMeters: 1500)
                    }

                Button("Poland")
                    .onClicked(.cancelPrevious) {
                        try await map.moveToRegion(
                            latitude: 52.1, longitude: 19.4, radiusMeters: 350_000)
                    }

                // What it DRAWS, cycled so all three can be seen.
                Button(kind == .standard ? "Street" : kind == .satellite ? "Satellite" : "Hybrid")
                    .onClicked {
                        kind =
                            kind == .standard
                            ? .satellite
                            : kind == .satellite ? .hybrid : .standard
                    }
            }
            .spacing(8)
            .horizontalAlignment(.center)

            HStack {
                SwitchRow("Traffic", $traffic)

                SwitchRow("Show me", $showsMe)
            }
            .spacing(16)
            .horizontalAlignment(.center)

            // Zoom and drag both off at once, which is what "locked" means to
            // a user.
            SwitchRow("Locked", $locked)
                .horizontalAlignment(.center)

            // The opening region is the INITIALIZER's, not an `.onCreated` act:
            // written here it is kept until the platform's map has connected,
            // while an act can land an instant too early and be overwritten
            // by the map's own opening view.
            Map(latitude: 50.0617, longitude: 19.9373, radiusMeters: 1500)
                .aim(map)
                // What the map draws, and whether the user may move it.
                .mapType(kind)
                .showsTraffic(traffic)
                .showsUserLocation(showsMe)
                .isZoomEnabled(!locked)
                .isScrollEnabled(!locked)
                .markers {
                    Marker("Wawel Castle")
                        .subtitle("Wawel 5")
                        // What the marker stands for, which is what decides the
                        // icon the platform draws for it.
                        .type(.place)
                        .location(latitude: 50.0540, longitude: 19.9354)
                        .onSelected { said = "pin: Wawel Castle" }
                        .onDetailsClicked { said = "details: Wawel Castle" }

                    Marker("Main Market Square")
                        .subtitle("Main Market Square 1/3")
                        .type(.searchResult)
                        .location(latitude: 50.0617, longitude: 19.9373)
                        .onSelected { said = "pin: Main Market Square" }
                }
                .onMapClicked { location in
                    said = "map: \(rounded(location.latitude)), \(rounded(location.longitude))"
                }
                .height(300)

            Text(said)
                .fontSize(12)
                .fontFamily("Menlo")
                .textColor(Palette.accent)
        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("`Map` is drawn by the platform's own map where there is one - "
                + "`MKMapView` on Apple. Elsewhere, the Web included, the application "
                + "registers its own map with the host, the pins as its children.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Where the map opens is the initializer's: that region is kept until the "
                + "platform's map has connected, while the same move from `.onCreated` can "
                + "land an instant too early and be overwritten. Moving later is the act "
                + "the buttons perform - `moveToRegion` through the map's `@Aim`, with the "
                + "radius in meters.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }

    // listing: MapSample
    /// Four decimal places - about eleven meters - so a tapped point reads as
    /// a coordinate rather than a river of digits.
    private func rounded(_ degrees: Double) -> Double {
        (degrees * 10_000).rounded() / 10_000
    }
    // listing: end
}
