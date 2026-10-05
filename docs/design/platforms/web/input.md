# Input on the Web

What the user does with the mouse, a finger, a pen or the keyboard reaches an
element as the host layer hears it ([the runtime](../../host/runtime.md)):
the element says what it listens for (`MountedElement.hearing`), and the host
turns the page's events into what the host layer hears (`hear`).

## Taps

A tap is the element's `click`, the run of clicks its count. An element the
user taps that is no control of the browser's own is a button for assistive
technology and the keyboard: it takes the focus, and Return or Space pressed
on it is a tap - a tap assistive technology makes, which the host layer
answers at once whatever the count asked for. The pointer's events are the
DOM's `pointerenter`, `pointerleave`, `pointermove`, `pointerdown` and
`pointerup`, where the pointer is told from the element's top left corner.

A listener is hung once for each kind the element asks for, and what it hears
reaches the element only while the element still asks.

## What takes no input

An element that ignores input takes no pointer events, nor does anything in
it, so what lies under it takes them: `pointer-events: none`. A layout that
lets input through takes none beside its children, while each child takes its
own.
