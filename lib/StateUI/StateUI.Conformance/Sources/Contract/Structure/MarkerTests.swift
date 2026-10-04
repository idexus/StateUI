// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `MarkerContract` on a host: a marker stands on its map where the tree puts it, with its label, address and kind, and a
/// click on it, or on its details, is heard.
@_spi(Host) public enum MarkerTests: ConformanceFamily {
    public static let name = "Marker"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("aPinStandsOnItsMapAsTheTreeSays", proves: [
                Covered(MarkerContract.self), Covered(MarkerContract.label), Covered(MarkerContract.subtitle),
                Covered(MarkerContract.type), Covered(MarkerContract.location),
            ]) { s in
                s.start {
                    VStack {
                        Map(latitude: 52.23, longitude: 21.01, radiusMeters: 5_000).markers {
                            Marker("Home").subtitle("Nowy Świat 1").type(.place).location(latitude: 52.23, longitude: 21.02)
                        }.height(300)
                    }
                }
                let pin = try s.element(ofType: MarkerContract.nodeType)

                s.expect(try s.held(MarkerContract.label, on: pin), "Home")
                s.expect(try s.held(MarkerContract.subtitle, on: pin), "Nowy Świat 1")
                s.expect(try s.held(MarkerContract.type, on: pin), .place)
                s.expect(try s.held(MarkerContract.location, on: pin), Location(latitude: 52.23, longitude: 21.02))
            },
            ConformanceCase("aClickOnAPinAndOnItsDetailsIsHeard", proves: [
                Covered(MarkerContract.selected), Covered(MarkerContract.detailsClicked),
            ]) { s in
                let heard = Received<String>()
                s.start {
                    VStack {
                        Map(latitude: 52.23, longitude: 21.01, radiusMeters: 5_000).markers {
                            Marker("Home").location(latitude: 52.23, longitude: 21.02)
                                .onSelected { heard.values.append("pin") }
                                .onDetailsClicked { heard.values.append("details") }
                        }.height(300)
                    }
                }
                let pin = try s.element(ofType: MarkerContract.nodeType)

                try s.perform(.activate, on: pin)
                s.settle { heard.values == ["pin"] }
                try s.perform(.open, on: pin)
                s.settle { heard.values.count == 2 }
                s.expect(heard.values, ["pin", "details"])
            },
        ]
    }
}
