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

## A placing run

A ZStack whose children a placing run stands - an engine's - stands each
where the run says: absolutely, in its rectangle, drawn with the run's
transform under the child's own (`HostDrawingTransform.under`) and the run's
opacity. A ZStack draws its children back to front in the run's order
(`ZStackArithmetic.drawingOrder`) - each child, placed or not, takes its
z-index from it - so a child the run places never rises over a later one it
places none of.

## Scrolling

A ScrollView is the browser's own scrolling over one document, as tall as its
content and at least as tall as the view along the ways it scrolls, as wide
as the view across them: a track of `minmax(max-content, 1fr)`. A track of
`minmax(100%, max-content)` is the trap - a grid track grows to its maximum
only into room left over, so content wider than the view stands centred over
both its edges. The view's defaults - down, with its bars - stand from its
making, as an applier runs only for a member the tree states.

The user's movement is the host layer's (`ScrollMovement`): each `scroll` the
page raises moves it, a pointer down holds it, and the display's frames report
where it went and that it came to rest. An offset the tree writes scrolls the
element at once, and the `scroll` the element raises for it is no movement of
the user's: it is taken where it stands, not reported back.

## Where a view stands

A view the tree reads where it stands says so on the display's frame after
the page laid out or scrolled: its box in its layout parent's, its corner in
the page, and that corner from the window's room - the page below the bar
(`MountedElement.frameNumbers`). The host follows such a view's size with a
`ResizeObserver`, and every render and every scroll may move it.

## Values in CSS

Lengths are pixels, which CSS measures in the logical units StateUI's points
are. An inset's sides are CSS's logical sides: its leading side is the inline
start, so an element laid out right to left - `dir="rtl"` - turns its margin
and padding by itself. A colour is `rgb()` in sRGB with its alpha; a brush's
gradient is its first colour until gradients are drawn.
