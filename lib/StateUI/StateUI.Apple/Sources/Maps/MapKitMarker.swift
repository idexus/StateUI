// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import MapKit
@_spi(Host) import StateUI

/// A map's marker as MapKit holds it: its place, its label and subtitle as the marker's title and subtitle, its kind,
/// and the child it stands for, whose events it raises.
/// Design: docs/design/platforms/apple/maps.md#a-map
@_spi(Host) @MainActor
public final class MapKitMarker: NSObject, @MainActor MKAnnotation {
    /// The child the marker stands for.
    public let child: ChildElement<MarkerContract>

    /// Where the marker stands.
    @objc public dynamic var coordinate = CLLocationCoordinate2D()

    /// The child's label.
    @objc public dynamic var title: String?

    /// The child's subtitle.
    @objc public dynamic var subtitle: String?

    /// The child's kind.
    public private(set) var type = MarkerType.generic

    /// The marker of `child`, its values not yet taken.
    public init(_ child: ChildElement<MarkerContract>) {
        self.child = child
        super.init()
    }

    /// Takes the child's values again.
    public func take() {
        let location = child.value(MarkerContract.location) ?? Location(latitude: 0, longitude: 0)
        coordinate = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
        title = child.value(MarkerContract.label)
        subtitle = child.value(MarkerContract.subtitle)
        type = child.value(MarkerContract.type) ?? .generic
    }
}
