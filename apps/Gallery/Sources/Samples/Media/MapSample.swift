import StateUI

/// The platform's own map, with pins, a region to move to, and what it draws.
struct MapSample: SampleContent, ExampleContent {
    @State private var said = "tap the map, a marker, or its callout"

    @Aim(Map.self) private var map
    @State private var kind = MapType.street
    @State private var traffic = false
    @State private var showsMe = false
    @State private var locked = false

    static let id = "map"
    static let title = "Map"
    static let summary = "The platform's own map, with pins on it - and the region an act away."

    /// Held still: a map PANS, and the page's scroller would claim the drag -
    /// the rule every gesture sample follows.
    static let scrolls = false

    static let code = """
        @State private var said = "tap the map, a marker, or its callout"

        @Aim(Map.self) private var map
        @State private var kind = MapType.street
        @State private var traffic = false
        @State private var showsMe = false
        @State private var locked = false

        VStack {
            // What the map last said is read here, so every tap on it builds
            // this closure.
            DebugInfoLabel()

            HStack {
                Button("Old Town")
                    .onClicked {
                        try await map.moveToRegion(
                            latitude: 50.0617, longitude: 19.9373, radiusMeters: 1500)
                    }

                Button("Poland")
                    .onClicked {
                        try await map.moveToRegion(
                            latitude: 52.1, longitude: 19.4, radiusMeters: 350_000)
                    }

                // What it DRAWS, cycled so all three can be seen.
                Button(kind == .street ? "Street" : kind == .satellite ? "Satellite" : "Hybrid")
                    .onClicked {
                        kind = kind == .street ? .satellite
                            : kind == .satellite ? .hybrid : .street
                    }
            }

            HStack {
                SwitchRow("Traffic", $traffic)

                SwitchRow("Show me", $showsMe)

                // Both at once, which is what "locked" means to a reader.
                SwitchRow("Locked", $locked)
            }

            // Where it OPENS is the initializer's - kept until the platform's
            // map has connected. Moving later is the act the buttons perform.
            Map(latitude: 50.0617, longitude: 19.9373, radiusMeters: 1500)
                .aim(map)
                // What the map draws, and whether the reader may move it.
                .mapType(kind)
                .isTrafficEnabled(traffic)
                .showsUserLocation(showsMe)
                .isZoomEnabled(!locked)
                .isScrollEnabled(!locked)
                .pins {
                    Pin("Wawel Castle")
                        .address("Wawel 5")
                        // What the pin stands for, which is what decides the
                        // icon the platform draws for it.
                        .type(.place)
                        .location(latitude: 50.0540, longitude: 19.9354)
                        .onMarkerClicked { said = "marker: Wawel Castle" }
                        .onInfoWindowClicked { said = "callout: Wawel Castle" }

                    Pin("Main Market Square")
                        .address("Main Market Square 1/3")
                        .type(.searchResult)
                        .location(latitude: 50.0617, longitude: 19.9373)
                        .onMarkerClicked { said = "marker: Main Market Square" }
                }
                .onMapClicked { location in
                    said = "map: \\(location.latitude), \\(location.longitude)"
                }
                .height(300)

            Label(said)
        }
        """

    var content: any View {
        VStack {
            DebugInfoLabel()

            HStack {
                Button("Old Town")
                    .padding(14, 8)
                    .onClicked {
                        try await map.moveToRegion(
                            latitude: 50.0617, longitude: 19.9373, radiusMeters: 1500)
                    }

                Button("Poland")
                    .padding(14, 8)
                    .onClicked {
                        try await map.moveToRegion(
                            latitude: 52.1, longitude: 19.4, radiusMeters: 350_000)
                    }

                Button(kind == .street ? "Street" : kind == .satellite ? "Satellite" : "Hybrid")
                    .padding(14, 8)
                    .onClicked {
                        kind =
                            kind == .street
                            ? .satellite
                            : kind == .satellite ? .hybrid : .street
                    }
            }
            .spacing(8)
            .horizontalAlignment(.center)

            HStack {
                SwitchRow("Traffic", $traffic)

                SwitchRow("Show me", $showsMe)

                SwitchRow("Locked", $locked)
            }

            // The opening region is the INITIALIZER's, not an `.onCreated` act:
            // written here it is kept until the platform's map has connected,
            // while an act can land an instant too early and be overwritten
            // by the map's own opening view.
            Map(latitude: 50.0617, longitude: 19.9373, radiusMeters: 1500)
                .aim(map)
                // What the map draws, and whether the reader may move it.
                .mapType(kind)
                .isTrafficEnabled(traffic)
                .showsUserLocation(showsMe)
                .isZoomEnabled(!locked)
                .isScrollEnabled(!locked)
                .pins {
                    Pin("Wawel Castle")
                        .address("Wawel 5")
                        .type(.place)
                        .location(latitude: 50.0540, longitude: 19.9354)
                        .onMarkerClicked { said = "marker: Wawel Castle" }
                        .onInfoWindowClicked { said = "callout: Wawel Castle" }

                    Pin("Main Market Square")
                        .address("Main Market Square 1/3")
                        .type(.searchResult)
                        .location(latitude: 50.0617, longitude: 19.9373)
                        .onMarkerClicked { said = "marker: Main Market Square" }
                }
                .onMapClicked { location in
                    said = "map: \(rounded(location.latitude)), \(rounded(location.longitude))"
                }
                .height(300)

            Label(said)
                .fontSize(12)
                .fontFamily("Menlo")
                .textColor(Palette.accent)
        }
        .spacing(12)
    }

    var notes: Element? {
        VStack {
            Label("`Map` is an optional provider, drawn by the platform's own map where a "
                + "host provides one - `MKMapView` on Apple. GTK 4, Android Views and "
                + "WinUI 3 depend on a map library and a map service, and the Web has no "
                + "map element.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Where the map opens is the initializer's: that region is kept until the "
                + "platform's map has connected, while the same move from `.onCreated` can "
                + "land an instant too early and be overwritten. Moving later is the act "
                + "the buttons perform - `moveToRegion` through the map's `@Aim`, with the "
                + "radius in meters.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }

    /// Four decimal places - about eleven meters - so a tapped point reads as
    /// a coordinate rather than a river of digits.
    private func rounded(_ degrees: Double) -> Double {
        (degrees * 10_000).rounded() / 10_000
    }
}
