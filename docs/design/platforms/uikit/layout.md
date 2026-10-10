# Layout on UIKit

How the UIKit host stands the tree's views where the host layer's arithmetic
puts them.

## A layout and its children

A layout is a view of the host's own: it measures its children by the host
layer's arithmetic - a layout child by its own measurement, a control as
UIKit fits it - keeps what it measured until something in it changes, and
stands each child by its bounds and centre, on its way there where the
layout moves. A change that alters a size is measured again up to the
window; one that does not - a colour, a value - measures nothing.

## Scrolling

A ScrollView is a layout holding UIKit's own scroll view over the whole of
its room, and in it a document the host layer's scroll arithmetic sizes -
never smaller than the viewport, as wide as it where the scroller moves only
down - with the content standing in it; several children are stacked down in
one. A page's scroller let under the strip at its bottom or right keeps
that strip clear at its content's end (`keepEndClear`); its start and
offsets stay as they are.

What the user does to it is said on the display's frames by the host layer's
reading of it: a finger taking the scroller holds the movement, its moves are
joined until the next frame, and the movement rests where the finger lets go
without a throw, where a throw runs out, or once the scroller has stood still.
An offset the tree writes moves the scroller within its reach as the program's
move, heard by nobody; one written before the first layout waits for it.
