# Drawing on a canvas

A `Canvas` draws what its closure writes with `Draw`. Drawing code is a
closure, and a closure is the one thing the boundary to a host cannot carry,
so a drawing crosses as what that code calls: one record per canvas
operation, in order, which the host replays against its toolkit's own canvas.

## A drawing is a list of records

A record is a list of typed values: the operation first, as the number both
sides spell, then its arguments as the things they are. A number crosses as
a number, a flag as a bool, a colour as its four bytes, an alignment as its
member's number, and text only where an author wrote some. The drawing is
the list of those records, so it crosses as one `.values` holding one
`.values` per instruction.

```text
  Draw.fillColor(.cornflowerBlue)
  Draw.fillRoundedRectangle(x: 0, y: 0, width: 120, height: 40, cornerRadius: 8)

  [[0, #FF6495ED], [13, 0, 0, 120, 40, 8]]
```

Nothing is formatted on this side and nothing is parsed on arrival.

## The kinds are the contract

`DrawCommand.Kind` numbers every operation, and the host switches on the
same numbers, case for case. A case is added at the end only: one inserted
in the middle renumbers every case after it, and a drawing then replays the
wrong instructions without a word from either side. The kinds are grouped
in their declaration: what the canvas draws with, outlines, solid shapes,
text, and where the canvas draws.

## Settings hold until changed

The instructions run in the order they are written, and a setting holds
until the next of its kind: a `fillColor` paints every fill after it until
another `fillColor`. `saveState` remembers the colours, sizes and transforms
in force and `restoreState` puts them back, which is what keeps one rotated
shape from turning the rest of the drawing.

`DrawingBuilder` collects the statements of a closure in order and, unlike
`ViewBuilder`, has `buildArray`, so a plain `for` loop inside a drawing
compiles: a chart draws a bar per value that way.

## Text in a box

`drawText` places text in a box rather than at a point. The box is what the
two alignments place the text in and what clips it, and its top is the top
of the box, not a baseline. `.start` and `.end` mean the box's left and
right, or top and bottom: a canvas draws in its own coordinates, not in a
reading direction.

## Themes in a drawing

A colour written `Color(light:dark:)` goes into its record as both halves.
The differ picks the half in force as it builds the canvas, which builds
again when the system theme changes; see
[a pair for each theme](colour-and-theme.md#a-pair-for-each-theme).
