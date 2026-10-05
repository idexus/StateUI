# Layout on the Web

The Web host lays out with the browser's own layout: CSS places every element,
measuring its words and pictures itself. StateUI's semantics of a layout - a
child's slot, its margin, its alignments, its stated sizes and their bounds
([layout](../../host/layout.md)) - are written as each element's CSS, so the
browser places a child where the host layer's arithmetic would.

## A layout is the browser's

A stack is a flexbox along its axis, its spacing the flexbox's gap and its
padding the element's own. A page, and the window's room, is a grid of one
cell that its one child stands in. A child of a stack takes its natural size
along the stack and never shrinks: a stack offers its children no less than
they need, as the host layer's stack does.

## A child's place

A layout writes each child's place as the child's own CSS: its margin, its
width and height, their least and most, and its alignment across its slot -
in a grid's cell along both axes. Start, centre and end are CSS's start,
center and end; a filling child stretches, unless a stated or a most size
stops it short of its slot, when it stands in the middle, as the host layer
places it. A hidden child is `hidden`, which takes it out of the layout: it
takes no room and no spacing.

## Children in order

A layout whose children changed stands each in its place in turn, from the
first: each is put at its index, moving from wherever it stood, and one
already there stays. After the first `n` steps the first `n` elements are the
first `n` children, so the order is right however it was before. Asking which
child stood at an index before a move is the trap: the moves before it in the
same pass shift the elements, and three children turned about - `[a, b, c]`
to `[c, b, a]` - stand `[c, a, b]`.

## Values in CSS

Lengths are pixels, which CSS measures in the logical units StateUI's points
are. An inset's sides are CSS's logical sides: its leading side is the inline
start, so an element laid out right to left - `dir="rtl"` - turns its margin
and padding by itself. A colour is `rgb()` in sRGB with its alpha; a brush's
gradient is its first colour until gradients are drawn.
