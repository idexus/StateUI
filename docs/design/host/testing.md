# An application's tests

`StateUITesting` is what an application's tests import to show a page and use
it as its user does: a window found by what automation knows a view by, acts a
user makes, and reads of what a view holds. It stands on the host layer's
driving - a driver (`HostDriver`) and the acts it does - which every host's
conformance suite drives its toolkit through, so what a test does on a window
is what a host's driver does on its toolkit. It links no conformance suite.

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
its bound, by the host layer's one rule (`InputWords.held`); a stepper takes
a step its buttons take (`ValueArithmetic.step`), none past an end; a day is
one its calendar offers and a time one a clock shows (`CalendarArithmetic`);
a color keeps its opacity only where the picker chooses it
(`ColorChoice.reported`); and the keyboard moved to a view leaves the last,
each element following the focus told where it now is, as a host tells it.
A question or a
file the page asks for is answered as a host answers an act it cannot
perform. One window stands at a time, as the core runs one application; a new
window closes the last (`HostDriver.close`), whose views are found no more.

## Closing a window

`TestWindow.close()` begins one teardown and waits for it. The renderer lets
go of the application and its tree, cancels the runs owned by that tree and
starts its disappearing and destroying handlers. The driver's window closes
and its controls leave. Replacing a window and releasing the last window
begin the same teardown; an explicit close can await it. A window records
the application registration it started, so its late cleanup cannot close
a later window, even when the tests reuse one driver.

The wait follows that teardown's tasks, including cancelled owned runs and
lifecycle work, rather than a global count of runs. Unrelated work does not
hold it. A second close waits for the same teardown. The wait fails after
ten seconds if cleanup has not finished, and respects cancellation of the
waiting task; neither failure opens the closed window again. Deinitializing
a window begins cleanup but cannot wait for asynchronous handlers. Tests
that inspect their effects call `close()` explicitly.

A driver keeps draining its toolkit and the UI thread's jobs after closure
while the test waits, without rendering another page. A closed host offers
no controls or new host acts to the handlers: an awaited host act fails
with `StateUIError.notPerformed`, and one with no waiter is diagnosed and
left out. Cleanup that needs those must finish before the host is closed.

## The acts a window offers

A test's window offers the acts it does and no others: its own `UserAct`, the
part of the driver's acts that the window performs with no toolkit. An act the
window cannot do is no case to write, rather than a failure at run time; a
host's driver does every act of the driver's, which the window's map onto.
A choice is made by the words the user sees - a picker's options - which the
window finds once among them and hands the driver as their place; words the
picker does not offer, or offers twice, fail naming them.

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
work run between the steps. Every run is numbered as it begins and knows the
run it descends from (`HandlerRun.origin`, runs.md), so the window waits on
the runs descending from one begun after the mark it took before the act
(`HostBoundary.runsUnderWay(since:)`) and on nothing descending from a run
begun before - a service the page began as it appeared runs on, and the work
it starts while the act runs is its own: neither holds the act. The handlers
an act raises descend from no run of the test's, whatever task the test acts
from - a task through a gate too - as every handler the host begins (runs.md,
`Renderer.start`). A run the
act began still under way after the window's patience, ten
seconds, fails the act, naming how many stand: a wait is bounded, and a run
meant to outlive its act belongs to the page's appearing. The window's own
start waits a second of frames alone. `motion: .none` makes a change show at
once, where a test reads what it changed with no frames of motion between;
the default motion animates as the application's does.

## What a view holds

A read names a contract member - `TextElementContract.text`,
`ToggleElementContract.isOn` - and answers the member's own type: what the view
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
