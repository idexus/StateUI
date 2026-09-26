// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// `PinContract` on a host: a pin stands on its map where the tree puts it, with its label, address and kind, and a
/// click on it, or on its details, is heard.
@_spi(Host) public enum PinTests: ConformanceFamily {
    public static let name = "Pin"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("aPinStandsOnItsMapAsTheTreeSays", covers: [
                Covered(PinContract.self), Covered(PinContract.label), Covered(PinContract.address),
                Covered(PinContract.type), Covered(PinContract.location),
            ]) { s in
                s.start {
                    VStack {
                        Map(latitude: 52.23, longitude: 21.01, radiusMeters: 5_000).pins {
                            Pin("Home").address("Nowy Świat 1").type(.place).location(latitude: 52.23, longitude: 21.02)
                        }.height(300)
                    }
                }
                let pin = try s.element(ofType: PinContract.nodeType)

                s.expect(try s.held(PinContract.label, on: pin), "Home")
                s.expect(try s.held(PinContract.address, on: pin), "Nowy Świat 1")
                s.expect(try s.held(PinContract.type, on: pin), .place)
                s.expect(try s.held(PinContract.location, on: pin), Location(latitude: 52.23, longitude: 21.02))
            },
            ConformanceCase("aClickOnAPinAndOnItsDetailsIsHeard", covers: [
                Covered(PinContract.pinClicked), Covered(PinContract.pinDetailsClicked),
            ]) { s in
                let heard = Received<String>()
                s.start {
                    VStack {
                        Map(latitude: 52.23, longitude: 21.01, radiusMeters: 5_000).pins {
                            Pin("Home").location(latitude: 52.23, longitude: 21.02)
                                .onPinClicked { heard.values.append("pin") }
                                .onPinDetailsClicked { heard.values.append("details") }
                        }.height(300)
                    }
                }
                let pin = try s.element(ofType: PinContract.nodeType)

                try s.perform(.activate, on: pin)
                s.settle { heard.values == ["pin"] }
                try s.perform(.open, on: pin)
                s.settle { heard.values.count == 2 }
                s.expect(heard.values, ["pin", "details"])
            },
        ]
    }
}
