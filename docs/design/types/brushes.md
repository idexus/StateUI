# Brushes

A brush is what a shape, a border or a background is painted with: one
colour, a gradient along a line, or a gradient out from a point.

## Three kinds

A `Brush` is made by one of three factories: `.solidColor`,
`.linearGradient` and `.radialGradient`. It holds its kind, the geometry
that kind is drawn over, and its stops. A solid brush is one stop whose offset is never asked for and does
not travel; it exists for a property that takes only a brush.

## As a host is handed it

A brush crosses as what it is: a list of typed values, the kind first as the
number both sides spell, then the geometry as one run of numbers, then an
offset and a colour for each stop.

```text
  solid    [1, colour]
  linear   [2, [x1, y1, x2, y2], offset, colour, offset, colour, ...]
  radial   [3, [cx, cy, r],      offset, colour, offset, colour, ...]
```

The host builds its own toolkit's brush from these parts and parses nothing.
A gradient spelled as text would put the definition of a gradient inside
whichever parser reads it, and one that read it only in part would draw
nothing, or the wrong thing, without saying a word. The kinds number from 1;
see [a kind first](vocabularies.md#a-kind-first).

## Geometry in fractions

A gradient's points are fractions of the thing being painted, not device
units: `Point(0, 0)` is its top left corner and `Point(1, 1)` its bottom
right, so one brush paints any size the same way. A linear gradient left
without points runs from `Point(0, 0)` to `Point(0, 1)`, straight down. A
radial gradient's centre is a fraction of the painted thing and its radius a
fraction of its size, from `Point(0.5, 0.5)` and 0.5 unless said.

## Themed stops

A stop's colour may be a `Color(light:dark:)` pair. It crosses as both
halves until the differ builds the element wearing the brush and picks the
half in force, and that element builds again when the system theme changes;
see [a pair for each theme](colour-and-theme.md#a-pair-for-each-theme).
