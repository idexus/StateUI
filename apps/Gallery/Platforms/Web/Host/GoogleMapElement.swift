// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import StateUI
import StateUIWeb

/// A map of Google's, the gallery's own on the Web, where the browser has none: `<gallery-map>` of
/// Page/google-map.js over the Maps JavaScript API, its markers the map's children.
///
/// The key the API asks for is the application's, never the repository's: Page/google-maps-key.js, which git keeps
/// out, sets `StateUI.googleMapsKey` - and `StateUI.googleMapsMapId`, where the key's project has a map of its own.
@MainActor
final class GoogleMapElement: WebControl {
    let element = WebPageElement(tag: "gallery-map")

    private let reports: WebReports<MapContract>

    /// Each marker shown, by the number the element knows it by.
    private var markers: [Int: WebChild<MarkerContract>] = [:]
    private var numbers: [WebChild<MarkerContract>: Int] = [:]
    private var nextNumber = 1

    /// How many times the map was sent somewhere, so the same place asked twice moves it twice.
    private var moves = 0

    init(_ reports: WebReports<MapContract>) {
        self.reports = reports
        element.listen("mapclick", words: { [weak self] words in
            let place = words.split(separator: " ").compactMap { Double($0) }
            guard let self, place.count == 2 else { return }
            self.reports.raise(MapContract.mapClicked, Location(latitude: place[0], longitude: place[1]))
        })
        element.listen("markerselect", words: { [weak self] number in
            self?.marker(number)?.reports.raise(MarkerContract.selected)
        })
        element.listen("markerdetails", words: { [weak self] number in
            self?.marker(number)?.reports.raise(MarkerContract.detailsClicked)
        })
    }

    /// The region the map opens on.
    func show(_ region: MapRegion?) {
        element.setAttribute("region", region.map(Self.written))
    }

    /// Slides the map until it shows `region`.
    func move(to region: MapRegion) {
        moves += 1
        element.setAttribute("moving-to", "\(Self.written(region)) \(moves)")
    }

    /// Sets an attribute the element reads as on or off.
    func set(_ name: String, _ on: Bool) {
        element.setAttribute(name, on ? "" : nil)
    }

    /// How the world is drawn.
    func show(_ type: MapType?) {
        let name = switch type ?? .standard {
        case .standard: "standard"
        case .satellite: "satellite"
        case .hybrid: "hybrid"
        }
        element.setAttribute("map-type", name)
    }

    /// Shows `children` as the map's markers, a line each - its number, where it stands, its kind, its label and
    /// what is under the label - so the element keeps a marker the same for as long as its child lives.
    func show(_ children: [WebChild<MarkerContract>]) {
        var kept: [WebChild<MarkerContract>: Int] = [:]
        markers = [:]
        let lines = children.compactMap { child -> String? in
            guard let location = child.value(MarkerContract.location) else { return nil }
            let number = numbers[child] ?? nextNumber
            if number == nextNumber { nextNumber += 1 }
            kept[child] = number
            markers[number] = child
            let kind = switch child.value(MarkerContract.type) ?? .generic {
            case .generic: "generic"
            case .place: "place"
            case .saved: "saved"
            case .searchResult: "searchResult"
            }
            return [String(number), String(location.latitude), String(location.longitude), kind,
                    Self.line(child.value(MarkerContract.label)), Self.line(child.value(MarkerContract.subtitle))]
                .joined(separator: "\t")
        }
        numbers = kept
        element.setAttribute("markers", lines.joined(separator: "\n"))
    }

    private func marker(_ number: String) -> WebChild<MarkerContract>? {
        Int(number).flatMap { markers[$0] }
    }

    /// `region` as the element reads it: latitude, longitude and radius in meters.
    private static func written(_ region: MapRegion) -> String {
        "\(region.latitude) \(region.longitude) \(region.radiusMeters)"
    }

    /// `words` on one line of a marker's, no tab or line break in them.
    private static func line(_ words: String?) -> String {
        String((words ?? "").map { $0 == "\t" || $0 == "\n" ? " " : $0 })
    }
}

// MARK: - Registration

extension GoogleMapElement {
    /// Adds the map for `MapContract`, its markers, and the act moving it. Said once, before the application runs.
    static func register() {
        StateUIControls.add(MapContract.self, create: { reports in GoogleMapElement(reports) }) { map in
            map.property(MapContract.region) { control, region in control.show(region) }
            map.property(MapContract.mapType) { control, type in control.show(type) }
            map.property(MapContract.showsTraffic) { control, on in control.set("traffic", on ?? false) }
            map.property(MapContract.showsUserLocation) { control, on in control.set("user-location", on ?? false) }
            map.property(MapContract.isZoomEnabled) { control, on in control.set("no-zoom", on == false) }
            map.property(MapContract.isScrollEnabled) { control, on in control.set("no-scroll", on == false) }
            map.raises(MapContract.mapClicked)
            map.children(MarkerContract.self, members: [
                MarkerContract.label, MarkerContract.subtitle, MarkerContract.location, MarkerContract.type,
                MarkerContract.selected, MarkerContract.detailsClicked,
            ]) { control, markers in
                control.show(markers)
            }
        }

        StateUIActs.add(MapContract.moveToRegion, on: GoogleMapElement.self) { map, latitude, longitude, radius in
            map.move(to: MapRegion(latitude: latitude, longitude: longitude, radiusMeters: radius))
        }
    }
}
