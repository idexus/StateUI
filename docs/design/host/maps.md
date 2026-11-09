# Maps

How a map shows a region and its markers alike on every host that draws one.

## A region

A region is a center and a radius in meters: the circle around the center
that the map shows whole. Whatever the map's proportions, its shorter side
spans the circle's width, twice the radius, and the longer side shows more
ground around it (`MapFraming.side(of:)`). A map read back says the same:
the circle its shorter side holds, from the ground its sides span
(`MapFraming.region(center:width:height:)`).

A map shows a region whose center stands on the globe - a latitude within
90° each way - and whose radius is a number above nought: a longitude is
taken round to within 180°, and a radius past a quarter of the way round the
globe is held there (`MapFraming.shown`). A region whose center is off the
globe or whose numbers are none is not shown: the map keeps what it shows,
as the engines raise on such a region rather than refuse it. An engine
holding a span to its own bounds - MapKit's 180° of latitude and 360° of
longitude, which a pole's longitudes reach past - does so in its adapter.

## What a map shows

A map's engine fits the region it is given to its view and measures ground
in its own projection, so the region read back is near the one given, never
equal to it: MapKit's radius comes back up to half a percent short, its
center exact. A case compares a region within a meter of the center and a
percent of the radius.

## A marker's look

A marker of a kind wears one hue and one symbol on every host drawing it
(`MarkerLook`): a plain one red with no symbol, a place blue with a
building, one the user saved yellow with a star, a search result purple with
a magnifying glass. The host draws the hue as its platform's own color of
that name, so a marker follows the platform's palette and its dark theme,
and it reads a marker's kind back by that color.

## A tap on the map

A tap on the map itself is the map's `locationTapped`; one on a marker, or on what
a marker opened, is the marker's. A double tap is the map's own zoom, no two
taps on it: the tap waits for a double tap to fail. The host hears the map's taps with a recognizer
of its own, beside the engine's, and what decides whether a tap is the
map's is a delegate apart from the map: MapKit's map is the delegate of its
own recognizers, and a map answering a recognizer's question itself would
answer it for every one of them, and a tap on a marker would choose no
marker.
