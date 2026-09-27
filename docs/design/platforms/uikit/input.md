# Input on UIKit

How the UIKit host hears what the user does to a view with a finger, a pen or
the pointer, and hands it to the host layer, which says what it means.

## Listening

A view listens only for what its element's handlers and channels ask to
hear: a gesture recognizer of UIKit's own for each kind - taps, the pointer,
a press dragged, a pinch - added as the tree asks for it and taken away as it
stops asking. Its recognizers recognize together with every other, so a pan
inside a scroller and a tap on a button both still happen. A view that
listens takes touches, which a label and a picture do not of themselves.

A tap is told with its place in its quick run of taps, as the touch counts
it; the host layer says the tap where a run reaches the count asked for. The
pointer is a hover's entering, moving and leaving, and a press - put down,
held however far it moves, lifted - told as it goes down and as it is let
go.

## A press dragged

UIKit recognizes a pan past its own distance; the host puts its press back
where it went down, on the window - which the view it moves does not move -
and hands the host layer the press and every move, which it tells as a
drag's start, moves and end, and a swipe where the end went far enough. A
pan UIKit takes away ends the drag as cancelled. A pinch is told step by
step - its scale since the last and where it is, as shares of the view's
size.
