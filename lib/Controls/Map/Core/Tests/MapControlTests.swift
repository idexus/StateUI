// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI
import StateUIMap

/// A map and its pins as the tree describes them, and what their host reports.
final class MapControlTests: XCTestCase {
    /// A map dressed with everything it can be given.
    private static func dressed() -> Map {
        Map(latitude: 52.2297, longitude: 21.0122, radiusMeters: 3000)
            .mapType(.hybrid)
            .isScrollEnabled(true)
            .isZoomEnabled(true)
            .isTrafficEnabled(false)
            .showsUserLocation(false)
            .pins {
                Pin("Royal Castle")
                    .address("Plac Zamkowy 4")
                    .type(.place)
                    .location(latitude: 52.2479, longitude: 21.0155)
                    .onPinClicked {}
                    .onPinDetailsClicked {}

                Pin("Second")
                    .label("Lazienki Park")
                    .location(latitude: 52.2151, longitude: 21.0355)
            }
            .onMapClicked { _ in }
    }

    /// Every member of its own a map and a pin declare reaches its host, but the act, which is called, not carried.
    func testAMapAndItsPinsCarryEveryMemberOfTheirOwn() {
        let patch = Renders().render(Self.dressed().body)
        let pins = patch.children.filter { $0.type == PinContract.nodeType }
        let carried = { (patch: HostPatch) in
            Set(patch.properties.keys.map(\.name) + (patch.events?.handlers.keys.map(\.name) ?? []))
        }

        XCTAssertEqual(
            Set(MapContract.members.map(\.name)).subtracting(carried(patch)), [MapContract.moveToRegion.name])
        XCTAssertEqual(pins.count, 2)
        XCTAssertEqual(Set(PinContract.members.map(\.name)).subtracting(pins.first.map(carried) ?? []), [])
        XCTAssertEqual(pins.map { $0.properties[PinContract.label.token] }, [.string("Royal Castle"), .string("Lazienki Park")])
        XCTAssertEqual(
            patch.properties[MapContract.region.token],
            MapRegion(latitude: 52.2297, longitude: 21.0122, radiusMeters: 3000).propValue)
    }

    /// Pins written again replace the ones before, and stand before the context menu's slot, which stays last.
    func testPinsReplaceThoseBeforeAndStandBeforeTheContextMenu() {
        let map = Map()
            .pins { Pin("Old") }
            .contextMenu { MenuItem("Share") }
            .pins { Pin("First"); Pin("Second") }

        XCTAssertEqual(
            map.node.children.map(\.type),
            [PinContract.nodeType, PinContract.nodeType, ContextMenuContract.nodeType])
        XCTAssertEqual(
            map.node.children.prefix(2).map { $0.props[PinContract.label.token] },
            [.string("First"), .string("Second")])
    }

    /// A second handler on a pin's event runs beside the first, never instead of it.
    func testASecondHandlerOnAPinRunsBesideTheFirst() {
        var seen: [String] = []
        let renders = Renders()
        let patch = renders.render(
            Map().pins {
                Pin("Office")
                    .onPinClicked { seen.append("first") }
                    .onPinClicked { seen.append("second") }
            }.body)

        renders.fire(patch.children.first?.events?.handlers[PinContract.pinClicked.token])

        XCTAssertEqual(seen, ["first", "second"])
    }

    /// A click on the map arrives where it fell; a report of another shape leaves the handler alone.
    func testAClickOnTheMapArrivesWhereItFell() {
        var seen: [Location] = []
        let renders = Renders()
        let patch = renders.render(Map().onMapClicked { seen.append($0) }.body)
        let clicked = patch.events?.handlers[MapContract.mapClicked.token]

        renders.fire(clicked, with: [.numbers([52.25, 21.01])])
        renders.fire(clicked, with: [.numbers([52.25])])

        XCTAssertEqual(seen, [Location(latitude: 52.25, longitude: 21.01)])
    }

    /// A style written for a map carries its own properties, as one written for any control does.
    func testAStyleForAMapCarriesItsOwnProperties() {
        let style = Style<Map>().mapType(.satellite).isZoomEnabled(false)

        XCTAssertEqual(style.node.type, MapContract.nodeType)
        XCTAssertEqual(style.node.props[MapContract.mapType.token], MapType.satellite.propValue)
        XCTAssertEqual(style.node.props[MapContract.isZoomEnabled.token], .bool(false))
    }

    /// A map's and a pin's members speak in plain words: the map shows the user's location, and a pin's events
    /// name what happened to it - a click on it, a click on its details - never how a marker's toolkit names them.
    func testTheMembersSpeakInPlainWords() {
        let map = Set(MapContract.members.map(\.name))
        let pin = Set(PinContract.members.map(\.name))

        XCTAssertTrue(map.contains("showsUserLocation"))
        XCTAssertFalse(map.contains("isShowingUser"))
        XCTAssertTrue(pin.isSuperset(of: ["pinClicked", "pinDetailsClicked"]))
        XCTAssertTrue(pin.isDisjoint(with: ["markerClicked", "infoWindowClicked"]))
    }

    /// A map and its pins are a provider's, and so are the members only a map provider gives: no base host has to
    /// realize them.
    func testAMapIsAProvidersAndNoBaseHostsRequirement() {
        XCTAssertEqual(MapContract.layer, .provider)
        XCTAssertEqual(PinContract.layer, .provider)
        XCTAssertEqual(MapContract.mapType.layer, .provider)
        XCTAssertEqual(MapContract.region.layer, .provider)
        XCTAssertEqual(MapContract.mapClicked.layer, .provider)
    }
}

extension HostEventUpdate {
    /// The handlers this update names, by event.
    var handlers: [Event: Int32] {
        switch self {
        case .replace(let handlers): handlers
        }
    }
}
