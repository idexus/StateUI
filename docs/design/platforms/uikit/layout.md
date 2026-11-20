# Layout on UIKit

How the UIKit host stands the tree's views where the host layer's arithmetic
puts them.

## A layout and its children

A layout is a view of the host's own: it measures its children by the host
layer's arithmetic - a layout child by its own measurement, a control as
UIKit fits it - keeps what it measured until something in it changes, and
stands each child by its bounds and center, on its way there where the
layout moves. A change that alters a size is measured again up to the
window; one that does not - a color, a value - measures nothing.

## A control born with a size

UIKit makes some controls at a size of their own - a stepper, a spinner, a
date picker - before any layout touches them. A view says where it stands
once a layout placed it, StateUI's or its toolkit's giving it a size
([where a view stands](../../host/runtime.md#where-a-view-stands)); read as
it is, a size the control was born with would pass for a layout's, and a
handler of its frame would hear the control at its parent's corner before
the layout placed it.

So the host reads UIKit's size only for a view no layout of StateUI's holds
(`UIKitElement.sizeUIKitGave`) - a page's root, which UIKit's own layout
sizes. A view a layout of StateUI's holds says where it stands once that
layout placed it, and never by its size.

## Scrolling

A ScrollView is a layout holding UIKit's own scroll view over the whole of
its room, and in it a document the host layer's scroll arithmetic sizes -
never smaller than the viewport, as wide as it where the scroller moves only
down - with the content standing in it; several children are stacked down in
one. A page's scroller let under the bars at any of its edges keeps them clear
(`UIKitScrollClearance.keep`): its content inset and its indicators' on every
edge, its offsets counted from its first content kept clear, and its end kept
where the clearance changes.

What the user does to it is said on the display's frames by the host layer's
reading of it: a finger taking the scroller holds the movement, its moves are
joined until the next frame, and the movement rests where the finger lets go
without a throw, where a throw runs out, or once the scroller has stood still.
An offset the tree writes moves the scroller within its reach as the program's
move, heard by nobody; one written before the first layout waits for it.

UIKit pulls a scroller's offset back within its reach whenever its frame is
set - set again to the same frame too - so the host sets the frame only where
it changed. What the user does to the scroller lays the page out again on the
next frame wherever a view reads the offset - a label saying how far down -
and a frame set every time would fold the rubber band at the edge back each
frame, under the finger still pulling it: the stretch would shake rather than
stretch.
