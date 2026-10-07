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
places it. The least size a control's look gives it - a button's, a
field's, a slider's - is its own size, and yields where the tree states a
size or a most, where the child fills its slot and in an area: CSS's least
wins over a stated size, so a button stated 30 high stood 36. A hidden child
is `hidden`, which takes it out of the layout: it takes no room and no
spacing.

## Children in order

A layout whose children changed stands each in its place in turn, from the
first: each is put at its index, moving from wherever it stood, and one
already there stays. After the first `n` steps the first `n` elements are the
first `n` children, so the order is right however it was before. Asking which
child stood at an index before a move is the trap: the moves before it in the
same pass shift the elements, and three children turned about - `[a, b, c]`
to `[c, b, a]` - stand `[c, a, b]`.

## Places that travel

A stack's, a grid's and a ZStack's children travel to their places by the
host layer's layout motion (`TravellingPlaces`, `LayoutMotion`): what the
layout says - travel, arrive, fade in as it joins - is the host layer's; the
browser only lays out. So the places are read around each call from the page.
Before the first change the call makes - a patch reaching an element, an
element leaving, a view hidden or shown - every child standing in a followed
layout is read where the browser laid it out (`WebPlacements.beforeChange`);
once the call's changes are all in, each layout the call arranged is read
again, and the host layer's motion takes each child from where it stood to
where it now stands. Both reads are one call to the page each, of the
children's places in their layout from its own layout - `offsetLeft`,
`offsetTop` and their size, which no transform moves.

A child is drawn where its place stands on the way: moved from where the
browser lays it out by a translation before its own transform, and sized as
the place passes through, its end margins making up the rest of its slot -
so the room it takes in its layout is its slot's from the first frame, and
everything around it stands where it is going. A view laying out words keeps
the size it is bound for and only moves. At rest the view's own CSS stands
again.

The trap: the place a child sets out from must be read before anything
moves it. Read after the call's changes, every child already stands at its
new place and nothing travels; read from a measurement kept since the last
change, a child the browser moved meanwhile - an image arriving, the room
resized - sets out from where it no longer is.

## A placing run

A ZStack whose children a placing run stands - an engine's - stands each
where the run says: absolutely, in its rectangle, drawn with the run's
transform under the child's own (`HostDrawingTransform.under`) and the run's
opacity. The matrix turns and scales the child about the middle of the place
the run gives it, so it is written again whenever that place's size changes,
not only its turn: a run worked out before its room was measured - a card half
a point wide - leaves nothing of itself behind once the next one sizes it. A ZStack draws its children back to front in the run's order
(`ZStackArithmetic.drawingOrder`) - each child, placed or not, takes its
z-index from it - so a child the run places never rises over a later one it
places none of. A child placed in its area again, with no run, takes back
its own opacity: the run's drawn opacity gives way to it, and a placing never
clears it - a ZStack child at opacity nought, a row's hidden press light,
would otherwise stand lit each time its row's look changes under the pointer.
A card the run places - a grid of its face and its shade - wears the run's
shade on its second layer, as every host does: drawn whole, the shade - a
black card in its corners - shows at the face's edges, and the more as a
press shrinks the face.

## Scrolling

A ScrollView is the browser's own scrolling over one document, as tall as its
content and at least as tall as the view along the ways it scrolls, as wide
as the view across them: a track of `minmax(max-content, 1fr)`. A track of
`minmax(100%, max-content)` is the trap - a grid track grows to its maximum
only into room left over, so content wider than the view stands centred over
both its edges. The view's defaults - down, with its bars - stand from its
making, as an applier runs only for a member the tree states.

Bars always shown are `overflow: scroll`, standing whether or not there is
anything to scroll to; bars never shown are hidden by the page's style.

The user's movement is the host layer's (`ScrollMovement`): each `scroll` the
page raises moves it, a pointer down holds it, and the display's frames report
where it went and that it came to rest. An offset the tree writes scrolls the
element at once, and the `scroll` the element raises for it is no movement of
the user's: it is taken where it stands, not reported back. Where it stands
is read back once written - the browser stops an offset past the end at the
end, and its `scroll` says that end, which waiting for the offset written
heard as the user's; an offset that moved nothing raises no `scroll`, so
nothing waits for one.

A scroller keeps the user's scrolling to itself only along the ways it
scrolls (`overscroll-behavior-x`, `-y`): reaching its end there, the page
around it does not scroll on. Across them the scrolling goes on to the
scroller around it - a listing scrolling across lets a wheel or a finger
moving down scroll the page it stands in. Kept both ways, a listing across a
page stopped the page under every swipe over it. A list of items keeps the
same rule.

## Where a view stands

A view the tree reads where it stands says so as soon as the page laid it
out - at the end of the call from the page that changed it, the layout read
then, and again when its `ResizeObserver` tells it moved, which the browser
does before it draws - and after a display frame that wrote a value or a
scroll: its box in its layout parent's content - a parent that scrolls
adding how far it scrolled, so a child's place there stays as it scrolls -
its corner in the page, and that
corner from the window's room - the page below the bar (`MountedElement.frameNumbers`). What
the report changes is rendered in the same call, so a page sized by its own
frame - the Gallery's tabs - never stands a frame at no width. A view the
browser lays out nowhere - a covered page - says nothing. The trap: a
padding, a spacing or a track on its way moves a child without resizing it,
which no observer of the page tells - so every frame that wrote something
counts as laid out.

## Values in CSS

Lengths are pixels, which CSS measures in the logical units StateUI's points
are. An inset's sides are CSS's logical sides: its leading side is the inline
start, so an element laid out right to left - `dir="rtl"` - turns its margin
and padding by itself. A colour is `rgb()` in sRGB with its alpha; a brush's
gradient is its first colour until gradients are drawn.
