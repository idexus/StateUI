# Input on WinUI

How the WinUI host hears what the user does to an element with a finger, a pen
or the mouse - a tap, the pointer, a press dragged, a pinch - and reports it
as the element's events ([a user's change](../../host/runtime.md#a-users-change)).
A control's own input - a button's click, a switch turned - is the control's,
and stays there ([controls](controls.md)).

## Listening

A view listens only for what its element's handlers and channels ask: taps
for a tap handler, the pointer for a pointer handler, a press dragged for a
pan, a swipe or a state a pan carries, a pinch for a pinch handler. The relay
hangs its handlers on the element once, each naming the view by its number,
and each asks what the view listens for as it runs; a view that stops
listening, or leaves the tree, takes them off again.

A panel draws nothing between its children, and WinUI hits nothing there. A
listening panel with no background of its own is painted clear, so a row
answers a click past its words as well as on them.

## Taps

WinUI tells a tap, and a second tap soon after as a double tap in place of a
tap. The relay counts a quick run: a tap within the system's double-click
time of the last one continues it. A view asking for `count` taps answers
each time the run reaches a multiple of it. A tap is handled where a view
listens for it, so a tappable row inside another answers alone.

## Pressed by assistive technology

A panel that listens for taps is a button to UI Automation: its peer offers
the invoke pattern, and pressing it runs the tap handler once, whatever
count the view asks for - as a screen reader's press, and a test's, do.

## A press dragged

A press of the primary button, or a finger or a pen down, becomes a drag once
it has moved past the system's drag distance; from there the view holds the
pointer, so the drag goes on outside it, and the drag is handled, so a view
dragged inside another drags alone. It is measured on the window's content,
where the view it moves does not move the measure. A drag says its phases -
began, moved by how far since it began, ended or cancelled - and a pan's
states move by that from where they stood as it began. Ended, it is a swipe
by the host layer's rule ([a swipe](../../host/runtime.md#a-swipe)). A pan
that asks for more than one pointer is not recognized.

## A pinch

A view that listens for a pinch takes WinUI's scale manipulation - two
fingers on a touch screen - and says each step's scale since the last, and
where, as shares of its size. Taking the manipulation keeps the platform's
own panning off that view's touches.
