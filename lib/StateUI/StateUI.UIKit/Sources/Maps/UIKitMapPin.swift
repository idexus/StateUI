// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
import MapKit
@_spi(Host) import StateUI

/// A map's pin as MapKit holds it: its place, its label and address as the marker's title and subtitle, its kind,
/// and the child it stands for, whose events it raises.
@MainActor
final class UIKitMapPin: NSObject, @MainActor MKAnnotation {
    let child: ChildElement<PinContract>
    @objc dynamic var coordinate = CLLocationCoordinate2D()
    @objc dynamic var title: String?
    @objc dynamic var subtitle: String?
    private(set) var type = PinType.generic

    init(_ child: ChildElement<PinContract>) {
        self.child = child
        super.init()
    }

    /// Takes the child's values again.
    func take() {
        let location = child.value(PinContract.location) ?? Location(latitude: 0, longitude: 0)
        coordinate = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
        title = child.value(PinContract.label)
        subtitle = child.value(PinContract.address)
        type = child.value(PinContract.type) ?? .generic
    }

    /// The marker's colour and symbol for a pin's kind.
    static func look(of type: PinType) -> (tint: UIColor, symbol: String?) {
        switch type {
        case .generic: (.systemRed, nil)
        case .place: (.systemBlue, "building.2.fill")
        case .savedPin: (.systemYellow, "star.fill")
        case .searchResult: (.systemPurple, "magnifyingglass")
        }
    }
}
#endif
