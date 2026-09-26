# Conformance on Android Views

How the conformance suite drives Android Views: `AndroidDriver` in the host's
test APK, one test for each family of cases in `AndroidConformanceTests`,
their verdicts written into the APK's files and held to `exports/marks/android`
by `test-android.sh`.

## What the driver does

A user's act goes through the path Android's own input takes into the host: a
button's and a toggle's `performClick`, a field's words replaced in its
editable text - which its watcher hears as it hears a key - and the keyboard's
action on a field, done or search as its return key says. The activity's
lifecycle is told as the activity tells it: onResume as a window comes to the
front, onPause as another application does, onPause and onStop as the user
leaves it, and its finishing as it closes.

A finger's and a mouse's input are motion events dispatched to the view, in
its pixels, as the window hands them on: a tap put down and lifted in the
view's middle, a run of taps each soon after the last; a pan put down in the
middle and moved by its offset in two steps; a pinch two fingers spreading or
closing about its point; a press, a drag and a lift where the case says; and
a mouse entering, moving over and leaving the view as its hovering.

## Layout

The test's root stands in no window, so no traversal lays it out and no
global layout is heard: the driver measures and places the root as a window's
traversal would, and tells the host it did, as the traversal's global layout
does. Whoever reads its frame then says it on the next display frame.

## The UI thread's messages

A test runs on the UI thread and holds it, so nothing posted to its looper
arrives while it runs: a web page's client, a choreographer's frame, a posted
callback. Each step of the driver runs the thread's own messages for a
moment - a looper nested in the test's turn, which a message posted for the
moment's end leaves - so they arrive as they do in an application, whose
thread returns to its looper between turns. A test's hand-wound clock gives
its own frames, and the choreographer's are not taken then.

## A message an item

A phone may end an application whose UI thread runs one message too long -
the CPH2363 ends one whose window stands while a message runs ten seconds
(`MainThread worked timeout`) - and a looper nested in a message never marks
that message done. So the runner runs the suite one item in each message of
the UI thread: each test alone, and a conformance family of more cases than an
item takes in parts, each part a message; a family's verdicts are gathered
until its last part writes them, one file a family.

## What the driver reads

A member's value is read from the view Android holds - a toggle's check, a
seek bar's progress, a text view's words, a view's visibility, alpha and
enabled state - never from what the host last wrote.
