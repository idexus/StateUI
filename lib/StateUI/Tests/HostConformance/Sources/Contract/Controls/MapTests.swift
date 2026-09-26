// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// `MapContract` on a host: a map shows the region the tree gives it and the one an act moves it to, the kind of map
/// and what the user may do with it as the tree says, and a click on it heard where it fell.
@_spi(Host) public enum MapTests: ConformanceFamily {
    public static let name = "Map"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("aMapShowsTheRegionTheTreeGivesIt", covers: [
                Covered(MapContract.self), Covered(MapContract.region),
            ]) { s in
                s.start { VStack { Map(latitude: 52.23, longitude: 21.01, radiusMeters: 5_000).height(300).id("map") } }

                s.expect(try s.held(MapContract.region, on: s.element("map")),
                         MapRegion(latitude: 52.23, longitude: 21.01, radiusMeters: 5_000))
            },
            ConformanceCase("anActMovesTheMapToARegion", covers: [
                Covered(MapContract.moveToRegion), Covered(MapContract.region), Covered(ButtonContract.clicked),
            ]) { s in
                let map = Aim(Map.self)
                let moved = Received<String>()
                s.start {
                    VStack {
                        Map(latitude: 52.23, longitude: 21.01, radiusMeters: 5_000).aim(map).height(300).id("map")
                        Button("Kraków").onClicked {
                            try await map.moveToRegion(latitude: 50.06, longitude: 19.94, radiusMeters: 2_000)
                            moved.values.append("moved")
                        }.id("move")
                    }
                }

                try s.perform(.activate, on: s.element("move"))
                s.settle { moved.values == ["moved"] }
                try s.settle {
                    try s.held(MapContract.region, on: s.element("map"))
                        == MapRegion(latitude: 50.06, longitude: 19.94, radiusMeters: 2_000)
                }
                s.expect(moved.values, ["moved"], "the act answered")
                s.expect(try s.held(MapContract.region, on: s.element("map")),
                         MapRegion(latitude: 50.06, longitude: 19.94, radiusMeters: 2_000))
            },
            ConformanceCase("aClickOnTheMapIsHeardWhereItFell", covers: [Covered(MapContract.mapClicked)]) { s in
                let heard = Received<Location>()
                s.start {
                    VStack {
                        Map(latitude: 52.23, longitude: 21.01, radiusMeters: 5_000)
                            .onMapClicked { heard.values.append($0) }.height(300).id("map")
                    }
                }

                try s.perform(.tap(count: 1), on: s.element("map"))
                s.settle { !heard.values.isEmpty }
                s.expect(heard.values.count, 1, "heard once")
            },
            Aspects.holds(MapContract.mapType, on: "Map", .street, then: .satellite),
            Aspects.holds(MapContract.isScrollEnabled, on: "Map", true, then: false),
            Aspects.holds(MapContract.isZoomEnabled, on: "Map", true, then: false),
            Aspects.holds(MapContract.isTrafficEnabled, on: "Map", false, then: true),
            Aspects.holds(MapContract.showsUserLocation, on: "Map", false, then: true),
        ]
    }
}
