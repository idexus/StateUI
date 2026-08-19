import StateUI

/// MAUI: Map and Pin - Microsoft.Maui.Controls.Maps.
struct MapSample: SampleContent {
    @State private var said = "tap the map, a marker, or its callout"

    @State private var map = ControlState<Map>()

    static let id = "map"
    static let title = "Map"
    static let summary = "The platform's own map, with pins on it - and the region an act away."

    /// Held still: a map PANS, and the page's scroller would claim the drag -
    /// the rule every gesture sample follows.
    static let scrolls = false

    static let code = """
        @State private var said = "tap the map, a marker, or its callout"

        @State private var map = ControlState<Map>()

        VStack {
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
            }

            // Where it OPENS is the initializer's - kept until the platform's
            // map has connected. Moving later is the act the buttons perform.
            Map(latitude: 50.0617, longitude: 19.9373, radiusMeters: 1500)
                .assign(map)
                .pins {
                    Pin("Wawel Castle")
                        .address("Wawel 5")
                        .location(latitude: 50.0540, longitude: 19.9354)
                        .onMarkerClicked { said = "marker: Wawel Castle" }
                        .onInfoWindowClicked { said = "callout: Wawel Castle" }

                    Pin("Main Market Square")
                        .address("Main Market Square 1/3")
                        .location(latitude: 50.0617, longitude: 19.9373)
                        .onMarkerClicked { said = "marker: Main Market Square" }
                }
                .onMapClicked { location in
                    said = "map: \\(location.latitude), \\(location.longitude)"
                }
                .heightRequest(300)

            Label(said)
        }
        """

    var content: Element {
        VStack {
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
            }
            .spacing(8)
            .horizontalOptions(.center)

            // The opening region is the INITIALIZER's, not an `.onLoaded` act:
            // written here it is kept until the platform's map has connected,
            // while the act - measured on Catalyst - lands an instant too
            // early and is overwritten by the map's own opening view.
            Map(latitude: 50.0617, longitude: 19.9373, radiusMeters: 1500)
                .assign(map)
                .pins {
                    Pin("Wawel Castle")
                        .address("Wawel 5")
                        .location(latitude: 50.0540, longitude: 19.9354)
                        .onMarkerClicked { said = "marker: Wawel Castle" }
                        .onInfoWindowClicked { said = "callout: Wawel Castle" }

                    Pin("Main Market Square")
                        .address("Main Market Square 1/3")
                        .location(latitude: 50.0617, longitude: 19.9373)
                        .onMarkerClicked { said = "marker: Main Market Square" }
                }
                .onMapClicked { location in
                    said = "map: \(rounded(location.latitude)), \(rounded(location.longitude))"
                }
                .heightRequest(300)

            Label(said)
                .fontSize(12)
                .fontFamily("Menlo")
                .textColor(Palette.accent)

            Label("The platform's own map draws this - MapKit here on Apple, Google "
                + "Maps on Android - which costs three honest lines: the app registers "
                + "the handler itself (builder.UseMauiMaps() in MauiProgram), an "
                + "Android app needs a Google Maps API key in its manifest or the map "
                + "stays a grey grid, and Windows has no Map handler at all.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Where the map OPENS is the initializer's - MAUI keeps that region "
                + "until the platform's map has connected, while the same act from "
                + "`.onLoaded` lands an instant too early and is overwritten. Moving "
                + "LATER is the act the buttons perform, `moveToRegion` on the view's "
                + "id - the radius in METERS, MAUI's own Distance unit.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }

    /// Four decimal places - about eleven meters - so a tapped point reads as
    /// a coordinate rather than a river of digits.
    private func rounded(_ degrees: Double) -> Double {
        (degrees * 10_000).rounded() / 10_000
    }
}
