# An application's tests

`StateUITesting` is what an application's tests import to show a page and use
it as its user does: a window found by what automation knows a view by, acts a
user makes, and reads of what a view holds. It stands on the conformance
suite's driving - a driver, the user's acts - so what a test does on a
window is what a host's driver does on its toolkit.

## A window with no toolkit

A `TestWindow` stands over StateUI's core and the host layer where `swift test`
runs, with no platform's toolkit: each view's native half keeps nothing, so
what a view holds is what the tree gave it, and a user's act is the report a
host makes of it - a click the button's `clicked`, words typed the field's
`textChanged` with its words, a switch turned its `toggled` with the value
it turned to, a tap the host layer's hearing of one. An act the window cannot
make of a view - one its contract does not take - fails naming the view. A
question or a file the page asks for is answered as a host answers an act it
cannot perform. One window stands at a time, as the core runs one
application; a new window takes the place of the last.

## A view found as automation finds it

A test finds a view by its `accessibilityIdentifier` - the handle automation
finds it by, stable across renders - or by the `@Aim` the page puts on it. A
found view is a query, not a mounted element: it is found again each time it
is used, so it stays the same view while the page builds again around it,
and a view no view is - or one two views are - is a failure naming it, never
a guess.

## An act and its work

An act is done once its work is: the handlers it raised, the work they began
and the frames they asked for - a second of frames on the window's own clock,
the UI thread's work run between them. `motion: .none` makes a change show at
once, where a test reads what it changed with no frames of motion between;
the default motion animates as the application's does.

## What a view holds

A read names a contract member - `TextualElementContract.text`,
`SwitchContract.isOn` - and answers the member's own type: what the view
holds as the window shows it, the branch's `isEnabled` included, and nil
where it holds none.

## The same test on every host

A window stands on a driver: with no toolkit the window's own, on a host its
conformance driver, which acts on the toolkit's controls and reads them back.
Each host's suite walks a window through its driver (`TestWindowWalk`) - a
click counted, words typed and a switch turned reaching their states, a view
found by its aim - so a test reads alike on every host and with no toolkit. A
host's suite runs its tests in its own loop, on its UI thread, so the walk
acts and settles there: the driver's steps turn the host's loop, and the
work an act began runs in them.
