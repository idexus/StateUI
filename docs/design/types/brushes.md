# Brushes

A brush is what a shape, an outline or a background is painted with: one
color, a gradient along a line, or a gradient out from a point.

## Three kinds

A `Brush` is made by one of three factories: `.solidColor`,
`.linearGradient` and `.radialGradient`. It holds its kind, the geometry
that kind is drawn over, and its stops. A solid brush is one stop whose offset is never asked for and does
not travel; it exists for a property that takes only a brush.

## As a host is handed it

A brush crosses as what it is: a list of typed values, the kind first as the
number both sides spell, then the geometry as one run of numbers, then an
offset and a color for each stop.

```text
  solid    [1, color]
  linear   [2, [x1, y1, x2, y2], offset, color, offset, color, ...]
  radial   [3, [cx, cy, r],      offset, color, offset, color, ...]
```

The host builds its own toolkit's brush from these parts and parses nothing.
A brush of one color of which nothing shows is clear (`HostBrush.isClear`):
a bar painted with it shows what lies behind it as it is.
A gradient spelled as text would put the definition of a gradient inside
whichever parser reads it, and one that read it only in part would draw
nothing, or the wrong thing, without saying a word. The kinds number from 1;
see [a kind first](vocabularies.md#a-kind-first).

## Geometry in fractions

A gradient's points are fractions of the thing being painted, not device
units: `Point(0, 0)` is its top left corner and `Point(1, 1)` its bottom
right, so one brush paints any size the same way. A linear gradient left
without points runs from `Point(0, 0)` to `Point(0, 1)`, straight down. A
radial gradient's center is a fraction of the painted thing and its radius a
fraction of its size, from `Point(0.5, 0.5)` and 0.5 unless said.

A radial gradient is a circle on every host: its radius is that fraction of
the painted thing's larger side, reaching as far across as down
(`HostBrush.reach`). A toolkit that reads a radius per axis in fractions of
the box would stretch the circle into an ellipse on anything not square, so
such a host is handed each axis's share of that one reach.

## Drawn by CSS

A host painting a box with CSS - the Web's boxes and bars, GTK's header bar -
takes a line's gradient as CSS does not: CSS takes an angle and stops along
its own gradient line, not two points. The angle is the direction from the
first point to the second in the box's pixels, clockwise from up, and each
stop moves onto CSS's line - the line through the box's middle, long enough
to reach its corners - where the stripe square to that direction meets it
(`CSSGradientLine`). Points that meet leave CSS's own line, straight down. The
angle follows the box's proportions, so such a box writes its gradient again
as its size changes.

## Themed stops

A stop's color may be a `Color(light:dark:)` pair. It crosses as both
halves until the differ builds the element wearing the brush and picks the
half in force, and that element builds again when the system theme changes;
see [a pair for each theme](color-and-theme.md#a-pair-for-each-theme).
