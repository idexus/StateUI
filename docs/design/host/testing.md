# An application's tests

`StateUITesting` is what an application's tests import to show a page and use
it as its user does: a window found by what automation knows a view by, acts a
user makes, and reads of what a view holds. It stands on the conformance
suite's driving - a driver, the user's acts - so what a test does on a
window is what a host's driver does on its toolkit.

## A window with no toolkit

A `TestWindow` stands over StateUI's core and the host layer where `swift test`
runs, with no platform's toolkit: each view's native half keeps nothing, so
what a view holds is what the tree gave it; the page hears it is shown as a
host's window tells it (`WindowPresentation`), so what it does on appearing
is done as the window opens; and a user's act is the report a
host makes of it - a click the button's `clicked`, words typed the field's
`textChanged` with its words, a switch turned its `toggled` with the value
it turned to, a tap the host layer's hearing of one. The window acts as the
user can, no further: an act the window cannot make of a view - one its
contract does not take - fails naming the view, and so does one the user
cannot make, on a view in a disabled branch or words into a read-only field,
saying why; words typed are held as the field holds them, in its case and to
its bound, by the host layer's one rule (`InputWords.held`). A question or a
file the page asks for is answered as a host answers an act it cannot
perform. One window stands at a time, as the core runs one application; a new
window closes the last (`HostDriver.close`), whose views are found no more.

## A view found as automation finds it

A test finds a view by its `accessibilityIdentifier` - the handle automation
finds it by, stable across renders - or by the `@Aim` the page puts on it. A
found view is a query, not a mounted element: it is found again each time it
is used, so it stays the same view while the page builds again around it,
and a view no view is - or one two views are - is a failure naming it, never
a guess.

## An act and its work

An act is done once its work is: the runs it began - the handlers it raised,
the work they began through a gate - to the last one's end, then the frames
they asked for, a second of them on the window's own clock, the UI thread's
work run between the steps. Every run is numbered as its gate takes it
(`RunSlot.taken`), so the window waits on the runs begun after the mark it
took before the act (`HostBoundary.runsUnderWay(since:)`) and on nothing
begun before - a service the page began as it appeared runs on, and holds no
act. A run the act began still under way after the window's patience, ten
seconds, fails the act, naming how many stand: a wait is bounded, and a run
meant to outlive its act belongs to the page's appearing. The window's own
start waits a second of frames alone. `motion: .none` makes a change show at
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
