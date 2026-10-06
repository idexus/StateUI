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

A view's recognizers hear together, with one exception: a stack lets the
user swipe back from anywhere in its page, and that swipe would take a drag
meant for the view - the page went back as the user moved a square. A view
listening for drags comes first: the stack's swipe waits for its drag to
fail, and the two never recognize together.

## A drag between views

A view's drag between views is UIKit's own pair of interactions on the view
itself, which asks no subclass and survives its layout. A view that can be
dragged holds a drag interaction - turned on, as an iPhone leaves it off -
whose item carries the view's words as a string; the session tells it the
drag began and, wherever it ended, that it ended. A view that takes drops
holds a drop interaction that takes a session carrying words: each update
says the drag is over it, an exit that it went, and a drop loads the words
and hands them over. The host layer's rule makes over once and no leave
after a drop.
