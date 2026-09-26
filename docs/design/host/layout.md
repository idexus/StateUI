# Layout in the runtime

StateUI owns its layouts' semantics: where a child of a stack, a grid, a
ZStack or a page goes is StateUI's arithmetic, the same on every
host, and a toolkit only measures its own views and moves them. [The
runtime](runtime.md) draws where layout sits in a frame; [motion](motion.md)
says how a child travels to the place this arithmetic gives it.

## The layout arithmetic

```text
  MountedElement.layoutValues      margin, alignments, stated sizes,
          |                        grid cell, area
          v
  LayoutChild                      the toolkit's child: those values, whether
          |                        it shows, and its size for an offered width
          v
  StackArithmetic   GridArithmetic   ZStackArithmetic   SingleChildArithmetic
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

The layout owns the margin both ways: it takes the margin out of the width it
offers a child and adds it to the size the child answers, and a toolkit's
child measures its own view alone. A margin taken out twice narrows the
offer - words wrap where they had room, and on WinUI a label measured at two
widths in one pass keeps the pass from settling.

## Measured once

A view keeps the sizes it measured, by the width its parent offered, until
something that can change them happens: its own content, its arrangement, or a
change beneath it. A parent offers a child one or two widths in a pass - its
natural width and the width it then lays it out in - so four kept answers
cover a pass and the next. The toolkit forgets them upward from the change to
the nearest room, and nothing beside the change is measured again. Which
change is which is one list on every host (`MountedElement.arrangedProperties`,
`unmeasuredProperties`): a property a parent reads into its child's place
arranges the parent again, and one that is only drawn - an opacity, a colour,
a toggle's state, a transform, what assistive technology meets - measures
nothing.

## A child measured

A layout measures a child the same way on every host: at its stated width,
within its bounds, so its words wrap to it - else at the smaller of the width
offered and its most width; and its size is its stated width and height
before what it measured, each within its bounds (`LayoutValues.offer`,
`sized`). A host measures its native view at that width and nothing more.

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

## Layers

A ZStack stands each shown child in its area and places it there as one child
stands in its room: by its alignments, margins and stated sizes. The area is
the room within the stack's padding, or the rectangle the child names - in
points from the room's top left, or in fractions of the room. The stack's
natural size is the room its neediest child needs at its natural size: a
rectangle in points to its far corner, a fraction as much as leaves the child
its natural size in its share, and anything else its size and margins.

## A placing run

A state that places a ZStack's children - a placing run - stands each child
where the run says, no size below nothing, drawn at the run's opacity within
0 and 1, and draws them back to front by their z-index, the earlier first
among equals, the children it places none of after them in their order
(`ZStackArithmetic.drawingOrder`, `HostPlacement.place`, `drawnOpacity`).

## Drawing order

A grid's and a ZStack's children can overlap, so their order is
the order they are drawn in: by `zIndex`, lower first, and children of the same
`zIndex` in the order the view wrote them. The mounted element keeps
`children` in that order and remembers the order written, so a sparse change
or a bound `zIndex` moving in a frame restacks them and arranges the layout
once; a runtime hands `children` to its toolkit in that order and needs no
`zIndex` of its own. A stack's children never overlap and keep the order
written.

## One child

A page or a pane holds one child within its padding. The child is
measured only where its natural size places it - on an axis it does not fill
and states no size for - so a child that fills both ways takes the room
whatever it would measure. A container with no shown child is its padding.

## A row beside a page

An arrangement's own row - a tabbed view's tabs where they stand in no window
row - stands across the top or the bottom of its room (`RowEdge`), and the
page takes the rest, never less than none; the arrangement's size is its
page's with the row's height added.

## A box

A box - a layout's, a button's, a colour box's, a rectangle's - is read the
same way on every host (`BoxArithmetic`): its corners' radii stand clockwise
from the top left, the order toolkits take them in, each never below nothing;
a corner rounds no more than half the side it rounds; its outline is a
rectangle where the tree asks none, a rounded one's radius never below
nothing; and the outline is drawn one wide where the tree gives it a colour
and no width, and not at all without a colour. A fill is read as the tree
sends it (`HostBrush`): a bare colour is one colour, a gradient's stops stand
between 0 and 1, and a gradient given no geometry runs top to bottom, or from
the middle to the edge. A line drawn in one colour takes the brush's first.
A fill a host draws for a control itself - a button's background, an accent -
keeps nine tenths of its opacity under the pointer and eight tenths pressed
(`PressedFill`), as the platforms' own controls fade theirs.

## A picture

An application's picture is the file its name stands for, looked for in one
order (`PictureArithmetic.files`): the name, then - for a PNG - an SVG of the
same name, which a host drawing vector pictures reads in its place. A host
drawing the picture itself stands it in its room by its aspect
(`PictureArithmetic.place`): fitted in or covering the room with its
proportions kept, or at its own size - each in the room's middle - or
stretched over the whole of it.

## A shape's own geometry

A line, a path, a polygon and a polyline draw a geometry of their own
numbers, which every host places in the room the shape's layout gives it by
one rule (`ShapeArithmetic`): scaled by the shape's aspect - to fit keeping
its proportions, to cover, each axis on its own, or not at all - and centred;
then moved by the shape's own transform, as a transform moves a view after
its layout, so a translation shows under every aspect. A geometry flat along
one axis, a straight line, fits by the axis it has.

A polygon's and a polyline's points are joined by lines as flat commands,
closed where the shape is, a point that is no number left out; a stroke's
dashes and gaps are measured in stroke widths
(`ShapeArithmetic.commands`, `dashLengths`).

## Right to left

A layout works its places out left to right, then turns each about the
middle of its room when it lays out right to left. That one rule is every
mirror a language written right to left needs: a row fills from the right, a
column's start stands at the right, a grid's column 0 is the rightmost, a
ZStack's area counts from the right edge, and padding and margins swap sides.
Nothing vertical changes, and no transform or drawing is turned.

The direction is the element's own `layoutDirection`, or - left at
`.inherited` - its parent's, and at the root the language's, as the host
reported the locale (`HostLocaleInfo.layoutDirection`). The mounted element
answers it (`MountedElement.layoutDirection`), and a runtime hands it to the
arithmetic with the room: each layout view keeps the direction its element
answers as it arranges its children, and the arithmetic takes it on every
call, with no default to forget. A direction that turns lays out again what
follows it - an element's own, every layout under it that inherits it; the
language's, the whole tree (`MountedTree.followTheLanguagesDirection`, which
a runtime calls after it reports the locale) - and nothing else.

## Scrolling

A scroller's content is held to the scroller's width when it scrolls only
down, or not at all, and offered no width when it scrolls across, where its
width is its own to decide. A filling child stated no width takes the width
it is held to. The document the content stands in is never smaller than the
viewport: along an axis the scroller scrolls it is as large as the content
with its padding and margin, and along any other it is the viewport's.

## An offset the tree writes

An offset the tree writes moves a scroller the same way on every host: one
that scrolls neither way stands at its origin; no offset, one that is no
number, or one it stands at already - within half a point, as the user's own
scrolling comes back as the state it wrote - moves nothing; any other moves
it, kept between its origin and what it reaches. An offset written before
the scroller's first layout waits for it, the last one written winning, and
one that scrolls neither way stands at its origin at once
(`WrittenScrollOffset`). A host moves its toolkit's scroller there as the
program's write.
