// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Android
import GalleryUI
import StateUI
import StateUIAndroid

/// A map of Google's, the gallery's own on Android, where the platform has none: com.stateui.gallery.GoogleMapView
/// over the Maps SDK for Android, its markers the map's children.
///
/// The key the SDK asks for is the application's, never the repository's: google-maps-key.properties beside
/// build.gradle.kts, which git keeps out, says it, and the manifest hands it to the SDK.
@MainActor
final class GoogleMapView: AndroidControl {
    let view: JavaObject

    private let reports: AndroidReports<MapContract>
    private let number: Int64

    /// Each marker shown, by the number the view knows it by.
    private var markers: [Int64: AndroidChild<MarkerContract>] = [:]
    private var numbers: [AndroidChild<MarkerContract>: Int64] = [:]
    private var nextNumber: Int64 = 1

    private static let viewClass = Java.findClass("com/stateui/gallery/GoogleMapView")
    private static let make = Java.method(viewClass, "<init>", "(Landroid/content/Context;J)V")
    private static let showing = Java.method(viewClass, "show", "(DDDZ)V")
    private static let typing = Java.method(viewClass, "showType", "(I)V")
    private static let traffic = Java.method(viewClass, "showTraffic", "(Z)V")
    private static let userLocation = Java.method(viewClass, "showUserLocation", "(Z)V")
    private static let allowing = Java.method(viewClass, "allow", "(ZZ)V")
    private static let marking = Java.method(viewClass, "showMarkers", "(Ljava/lang/String;)V")
    private static let releasing = Java.method(viewClass, "release", "()V")

    /// Whether a hand may zoom the map, and pan it.
    private var zooms = true
    private var scrolls = true

    init(_ reports: AndroidReports<MapContract>) {
        self.reports = reports
        number = GalleryControls.reserve()
        view = Java.new(Self.viewClass, Self.make, .object(StateUIAndroid.context), .long(number))
        GalleryControls.hold(self, as: number)
    }

    isolated deinit {
        GalleryControls.forget(number)
        Java.call(view.reference, Self.releasing)
    }

    /// Shows `region`, sliding there when `animated`.
    func show(_ region: MapRegion?, animated: Bool = false) {
        guard let region else { return }
        Java.call(
            view.reference, Self.showing, .double(region.center.latitude), .double(region.center.longitude),
            .double(region.radiusMeters), .bool(animated))
    }

    /// How the world is drawn.
    func show(_ type: MapType?) {
        let kind: Int32 = switch type ?? .standard {
        case .standard: 0
        case .satellite: 1
        case .hybrid: 2
        }
        Java.call(view.reference, Self.typing, .int(kind))
    }

    func showTraffic(_ on: Bool) {
        Java.call(view.reference, Self.traffic, .bool(on))
    }

    func showUserLocation(_ on: Bool) {
        Java.call(view.reference, Self.userLocation, .bool(on))
    }

    /// Whether a hand may zoom the map and whether it may pan it; nil leaves one as it is.
    func allow(zooms: Bool? = nil, scrolls: Bool? = nil) {
        self.zooms = zooms ?? self.zooms
        self.scrolls = scrolls ?? self.scrolls
        Java.call(view.reference, Self.allowing, .bool(self.zooms), .bool(self.scrolls))
    }

    /// Shows `children` as the map's markers, a line each - its number, where it stands, its kind, its label and
    /// what is under the label - so the view keeps a marker the same for as long as its child lives.
    func show(_ children: [AndroidChild<MarkerContract>]) {
        var kept: [AndroidChild<MarkerContract>: Int64] = [:]
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
        Java.frame { Java.call(view.reference, Self.marking, .object(Java.string(lines.joined(separator: "\n")))) }
    }

    /// The view says its user tapped the map at a place.
    func clicked(latitude: Double, longitude: Double) {
        reports.raise(MapContract.mapClicked, Location(latitude: latitude, longitude: longitude))
    }

    /// The view says its user chose the marker of `number`.
    func selected(_ number: Int64) {
        markers[number]?.reports.raise(MarkerContract.selected)
    }

    /// The view says its user asked for the details of the marker of `number`.
    func detailed(_ number: Int64) {
        markers[number]?.reports.raise(MarkerContract.detailsClicked)
    }

    /// `words` on one line of a marker's, no tab or line break in them.
    private static func line(_ words: String?) -> String {
        String((words ?? "").map { $0 == "\t" || $0 == "\n" ? " " : $0 })
    }
}

// MARK: - Registration

extension GoogleMapView {
    /// Adds the map for `MapContract`, its markers, and the act moving it. Said once, as the library loads.
    static func register() {
        // listing: android.md.children
        StateUIControls.add(MapContract.self, create: { reports in GoogleMapView(reports) }) { map in
            map.property(MapContract.region) { control, region in control.show(region) }
            map.property(MapContract.mapType) { control, type in control.show(type) }
            map.property(MapContract.showsTraffic) { control, on in control.showTraffic(on ?? false) }
            map.property(MapContract.showsUserLocation) { control, on in control.showUserLocation(on ?? false) }
            map.property(MapContract.isZoomEnabled) { control, on in control.allow(zooms: on ?? true) }
            map.property(MapContract.isScrollEnabled) { control, on in control.allow(scrolls: on ?? true) }
            map.raises(MapContract.mapClicked)
            map.children(
                MarkerContract.self,
                properties: MarkerContract.label, MarkerContract.subtitle, MarkerContract.location, MarkerContract.type,
                events: MarkerContract.selected, MarkerContract.detailsClicked
            ) { control, markers in
                control.show(markers)
            }
        }
        // listing: end

        StateUIActs.add(MapContract.moveToRegion, on: GoogleMapView.self) { map, region in
            map.show(region, animated: true)
        }
    }
}
