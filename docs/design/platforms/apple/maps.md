# The map on Apple's platforms

AppKit and UIKit realize a Map alike: MapKit's map is the same on both, and
the package they share, `lib/StateUI/StateUI.Apple`, writes it once
(`MapKitView`, its markers `MapKitMarker`).

## A map

A Map is MapKit's own map ([the host layer's map rules](../../host/maps.md)).
It shows the region the tree gives it or an act slides it to - the circle its
shorter side spans (`MapFraming`) - the kind of map, traffic where the map has
roads, the user's own place once the user lets it be known, and its markers as
MapKit's markers: one kept for each child for as long as the child lives, its
values taken again as they change, chosen and opened on the marker. What the
map shows is read back the same way: the region its shorter side holds, the
kind drawn, whether traffic shows.

What differs is each platform's own and stays in its host, a subclass of the
shared map: the recognizer that hears a click or a tap on the map itself
beside MapKit's own, the details button a marker's callout shows - AppKit's
an `info.circle` button, UIKit's the details disclosure, whose tap the map's
delegate hears - and the platform's colours and symbol images a marker is
dressed in (`MarkerLook`).
