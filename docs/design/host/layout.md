# Layout in the runtime

StateUI owns its layouts' semantics: where a child of a stack, a grid, an
absolute layout or a page goes is StateUI's arithmetic, the same on every
host, and a toolkit only measures its own views and moves them. [The
runtime](runtime.md) draws where layout sits in a frame; [motion](motion.md)
says how a child travels to the place this arithmetic gives it.

## The layout arithmetic

```text
  MountedElement.layoutValues      margin, alignments, stated sizes,
          |                        grid cell, absolute bounds
          v
  LayoutChild                      the toolkit's child: those values, whether
          |                        it shows, and its size for an offered width
          v
  StackArithmetic   GridArithmetic   AbsoluteArithmetic   SingleChildArithmetic
          |                        pure: the same children in, the same
          v                        rectangles out
  [Rect?]  one per child, nil for a hidden one
          |
          v
  the toolkit's layout view        stands each child there, or on its way
                                   there through LayoutMotion
```

A layout's values are read off the element once, by the core, so every host
reads the same margin, alignment and stated size. The toolkit supplies only
what it alone knows: whether the child is shown, and how big its view is for a
width it is offered - a label wraps, an image keeps its ratio. The arithmetic
is pure, so a host calls it from its own layout pass - `layout()` on AppKit, a
`ViewGroup`'s layout on Android - and a test calls it with plain values.

## One axis of a slot

Along each axis a child has a slot: the room its layout offers it, less its
margin. A size the child states wins over every alignment and is held only by
its own least and most size. Without one, a filling child takes the slot and
any other takes its natural size, never more than the slot. Where the least
size is larger than the most, the least wins, so contradictory bounds cannot
leave a child with no answer. A child placed at its start sits at the slot's
start; at its end, at the end; centred, or filling but stopped short by a
stated or a most size, in the middle.

## Measured once

A view keeps the sizes it measured, by the width its parent offered, until
something that can change them happens: its own content, its arrangement, or a
change beneath it. A parent offers a child one or two widths in a pass - its
natural width and the width it then lays it out in - so four kept answers
cover a pass and the next. The toolkit forgets them upward from the change to
the nearest room, and nothing beside the change is measured again.

## Stacks

A stack sets its shown children one after another with its spacing between
them, inside its padding. Along its axis each child takes its natural size;
across, its slot's rule. A vertical stack offers each child its own width, so
wrapped text is measured at the width it will have; a horizontal stack offers
none, because the width is what the children decide. A hidden child takes no
room and no spacing.

## Grids

A grid has as many rows and columns as it defines, or as its children reach,
whichever is more; an undefined track is a proportional track of one share.
A child's cell is its row and column, clamped into the grid, spanning its
spans.

## Tracks

A fixed track is its length. An automatic track is as large as its largest
child that spans that track alone. A proportional track divides what the
fixed and automatic tracks and the spacing leave, by its share; measured with
no room given, a proportional track is as large as its largest one-track
child, so the grid's natural size holds every child. A share of nothing still
counts as a sliver, so no division is by zero.

The columns are settled first, and a row measures each of its children at
the width of the columns it stands in, so words that wrap in a column make
their row as tall as they will stand. A grid measured for a width narrower
than its natural one shares that width among its columns as its placement
would, and its rows are measured at those widths; its natural width stays
its children's.

## Absolute bounds

An absolute layout stands each shown child at its own bounds: x, y, width and
height, a negative size being the child's natural one. A proportional flag
makes a size a fraction of the layout's own and a position a fraction of the
room left beside the child, so a position of one puts the child against the
far edge. The layout's natural size is the room its children's bounds reach at
their natural sizes, whatever width it is offered.

## One child

A page, a border or a pane holds one child within its padding. The child is
measured only where its natural size places it - on an axis it does not fill
and states no size for - so a child that fills both ways takes the room
whatever it would measure. A container with no shown child is its padding.

## Scrolling

A scroller's content is held to the scroller's width when it scrolls only
down, or not at all, and offered no width when it scrolls across, where its
width is its own to decide. A filling child stated no width takes the width
it is held to. The document the content stands in is never smaller than the
viewport: along an axis the scroller scrolls it is as large as the content
with its padding and margin, and along any other it is the viewport's.
