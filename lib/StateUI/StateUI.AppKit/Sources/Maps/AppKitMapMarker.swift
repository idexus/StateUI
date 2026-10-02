// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
import MapKit
@_spi(Host) import StateUI

/// A map's marker as MapKit holds it: its place, its label and address as the marker's title and subtitle, its kind,
/// and the child it stands for, whose events it raises.
@MainActor
final class AppKitMapMarker: NSObject, @MainActor MKAnnotation {
    let child: ChildElement<MarkerContract>
    @objc dynamic var coordinate = CLLocationCoordinate2D()
    @objc dynamic var title: String?
    @objc dynamic var subtitle: String?
    private(set) var type = MarkerType.generic

    init(_ child: ChildElement<MarkerContract>) {
        self.child = child
        super.init()
    }

    /// Takes the child's values again.
    func take() {
        let location = child.value(MarkerContract.location) ?? Location(latitude: 0, longitude: 0)
        coordinate = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
        title = child.value(MarkerContract.label)
        subtitle = child.value(MarkerContract.subtitle)
        type = child.value(MarkerContract.type) ?? .generic
    }

    /// The marker's colour and symbol for a marker's kind.
    static func look(of type: MarkerType) -> (tint: NSColor, symbol: String?) {
        switch type {
        case .generic: (.systemRed, nil)
        case .place: (.systemBlue, "building.2.fill")
        case .saved: (.systemYellow, "star.fill")
        case .searchResult: (.systemPurple, "magnifyingglass")
        }
    }
}

/// The button a marker's callout shows for its details: a click on it is heard on the marker.
@MainActor
final class AppKitPinDetailsButton: NSButton {
    weak var pin: AppKitMapMarker?
}
#endif
