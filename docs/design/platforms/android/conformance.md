# Conformance on Android Views

How the conformance suite drives Android Views: `AndroidDriver` in the host's
test APK, one test for each family of cases in `AndroidConformanceTests`,
their verdicts written into the APK's files and held to `lib/StateUI/exports/marks/android`
by `test-android.sh`.

## What the driver does

A user's act goes through the path Android's own input takes into the host: a
button's and a toggle's `performClick`, a field's words selected and
typed over through the input connection it gives a keyboard - which its
watcher hears as it hears a key - and the keyboard's action on a field:
search on a search field, done on any other. The activity's
lifecycle is told as the activity tells it: onResume as a window comes to the
front, onPause as another application does, onPause and onStop as the user
leaves it, and its finishing as it closes.

A slider moves as TalkBack's user moves it: its own action setting its
progress, which it reports as the user's. A stepper's step is a tap on its
button, which a button turned off at an end does not take; the stepper is two
buttons with no field, so words typed into it do not apply. A scroller is
moved by Android's own `scrollTo`, outside a write of the program's, which the
host hears as the user's movement. A tab is tapped on the row of tabs.

A finger's and a mouse's input are motion events dispatched to the view, in
its pixels, as the window hands them on: a tap put down and lifted in the
view's middle, a run of taps each soon after the last; a pan put down in the
middle and moved by its offset in two steps; a pinch two fingers spreading or
closing about its point; a press, a drag and a lift where the case says; and
a mouse entering, moving over and leaving the view as its hovering.

## Layout

The test's root stands as the test activity's content, but the host the
driver makes hears no traversal of that window (the window's listener belongs
to the activity's start): the driver measures and places the root at once, as
a window's traversal would, and tells the host it did, as the traversal's
global layout does. Whoever reads its frame then says it on the next display frame.

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
enabled state, its translation back in points, its rotation, scale and pivot,
the words its accessibility node carries as TalkBack reads them, a text
view's size in the scaled points the host sets it in, its bold and italic and
its colour - never from what the host last wrote. A colour is read from the
window as the user sees it, the render thread's clips and outlines included
(`PixelCopy`, once the window has drawn): a software drawing of the view
leaves an outline's cut out. The test window stands on a colour of its own,
which reads as nothing. What Android does not hold
stays unread, with why: a heading's level, where Android marks a heading, a
typeface's family, which keeps no name, and a stepper's range, which its
buttons do not hold.

A run of a text's words is its text view's spans over the letters the host
layer's runs place it at (`RunPlace`), the view's own look where none is.
A window's title is the activity's. A tab's title is the words on its tab and
its icon the picture the tab shows, told by its very pixels among the
pictures the suite shows; the tab chosen is the one marked selected, as
TalkBack tells it. A scroller's offset is where Android's scrollers stand.

The rest a view holds is read through one reader, `TestRead`, by the name of
what is asked, in the units Android keeps it in: a text view's lines,
ellipsis, gravity, letter spacing in pixels, line spacing, paint flags, hint,
selection and kind of input; a view's padding in whole pixels, back to whole
points; a layout's clipping to its outline, a scroller's bars, a picture's
scale type, a control's tint. A date field's day or time is read from the
words it shows, in the platform's own form, and whether its dialog shows from
the dialog; the user picks in that dialog and presses its OK, and Back
cancels it. What StateUI draws in its own views and
drawables - a shape's paint, a layout's box - and where StateUI's layout places
the children hold nothing of Android's: they do not apply here, each proven by
its effect in another case.

## Menus

A window's menus are read from the toolbar's menu of the stack showing its
visible page, its submenus alone; a view's context menu is opened into an
empty menu, as a long press opens it. An entry or an action is chosen and read
by its item's id - its element's place (`menuPlace`) - never by its words:
`performIdentifierAction`, which runs nothing for one that cannot be chosen,
and the item's words, whether it can be chosen, whether its words are in the
error colour. What the item keeps no trace of stays unread: a picture's name.
Whether an action stands on the bar or behind the overflow, and whether its
words show beside its picture, are read from the bar as Android lays it out
(`TestMenus.laidOut`); on a screen narrower than 480 points Android shows no
words beside a picture, and that stays unread.

## Running the stale families

The device reads no repository, so `STATEUI_STALE_ONLY=1` is the script's to
answer: it runs the families whose verdict files in `lib/StateUI/exports/marks/android`
open with another revision than `.scripts/Marks/revision.sh` gives, or with
none, and takes only theirs off the device.

## What goes past Android

The driver hands the activity's lifecycle - the window's phases, its closing -
to the host's own entry, as no activity moves in a test's window, a split
view's sidebar toggle to the host's own entry, a document picker's answer to
the relay's result path, as no picker is shown, and a drag between views and
documents dropped to the drag listeners' reports, as a test can make no drag
event. A few reads are the host's or its relay's own: a slider's range,
which the SeekBar keeps only as steps, a stepper's value, which its two
buttons do not hold, a picker's rows, a split view's
showing sidebar and its colour, an ItemsView's selection mode, a date
picker's bounds and a date or time picker's format, what the relay keeps of
a dialog, the document picker it holds and what it launched. The driver
names each (`byHost`), and a member a case proves only through them is
the host's own - ✓ - never ✅. A frame report reads where Android holds the
view, not where the host placed it last.
