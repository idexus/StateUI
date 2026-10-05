# Input on the Web

What the user does with the mouse, a finger, a pen or the keyboard reaches an
element as the host layer hears it ([the runtime](../../host/runtime.md)):
the element says what it listens for (`MountedElement.hearing`), and the host
turns the page's events into what the host layer hears (`hear`).

## Taps

A tap is the element's `click`, the run of clicks its count. A click on a
`<label>` beside its control - a radio button's caption - is no tap of its
own: the browser clicks the control next, and that click is the one tap. An
element the
user taps that is no control of the browser's own is a button for assistive
technology and the keyboard: it takes the focus, and Return or Space pressed
on it is a tap - a tap assistive technology makes, which the host layer
answers at once whatever the count asked for. The pointer's events are the
DOM's `pointerenter`, `pointerleave`, `pointermove`, `pointerdown` and
`pointerup`, where the pointer is told from the element's top left corner.

A button pressed leaves the keyboard with the field being typed in, as a
native button takes no keyboard of a field: the page's press on a button is
not let move the focus while a field holds it, so the program taking the
on-screen keyboard down finds the field still holding it.

A listener is hung once for each kind the element asks for, and what it hears
reaches the element only while the element still asks.

A control answers every tap, however quickly the next follows: a button, a
field, a choice and an element the user taps take `touch-action:
manipulation`, so two taps in a row on a touch screen are two taps, never the
page's zoom - which the rest of the page keeps.

## A press dragged and a pinch

A view that hears a press dragged or a pinch takes the pointers pressed on it
from the page: it neither scrolls nor zooms the page under a finger
(`touch-action: none`), its words are not selected, and a pointer pressed on
it is captured, so its moves reach it wherever they go until it lets go. One
pointer is a press dragged by the host layer's rule (`DragRecognition`), past
four points for a mouse or a pen and ten for a finger, measured on the page -
the view it moves moves under it. A press dragged is no tap: its click is not
heard as one.

Two fingers are a pinch: its scale each step is how far apart they stand
against the step before (`PinchStep`), where their middle is in the view; a
second finger ends the drag the first began, cancelled. A trackpad's pinch
reaches the page as a wheel turned with a key held - each turn of a hundred
points a step of e - or, in Safari, as its gesture, whose scale it carries;
the page's own zoom is taken from it, and a wheel standing still a fifth of
a second ends it.

Dragging and dropping between views (`canDrag`, `onDrop`) waits on a rule
the hosts share: no host realizes it yet.

## What takes no input

An element that ignores input takes no pointer events, nor does anything in
it, so what lies under it takes them: `pointer-events: none`. A layout that
lets input through takes none beside its children, while each child takes its
own.
