# Maps

How a map shows a region and its markers alike on every host that draws one.

## A region

A region is a centre and a radius in meters: the circle around the centre
that the map shows whole. Whatever the map's proportions, its shorter side
spans the circle's width, twice the radius, and the longer side shows more
ground around it (`MapFraming.side(of:)`). A map read back says the same:
the circle its shorter side holds, from the ground its sides span
(`MapFraming.region(latitude:longitude:width:height:)`).

## What a map shows

A map's engine fits the region it is given to its view and measures ground
in its own projection, so the region read back is near the one given, never
equal to it: MapKit's radius comes back up to half a percent short, its
centre exact. A case compares a region within a meter of the centre and a
percent of the radius.

## A tap on the map

A tap on the map itself is the map's `mapClicked`; one on a marker, or on what
a marker opened, is the marker's. The host hears the map's taps with a recognizer
of its own, beside the engine's, and what decides whether a tap is the
map's is a delegate apart from the map: MapKit's map is the delegate of its
own recognizers, and a map that answered a recognizer's question itself
answered it for every one of them - a tap on a marker no longer chose the
marker.
