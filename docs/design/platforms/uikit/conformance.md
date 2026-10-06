# Conformance on UIKit

How the conformance suite drives UIKit: `UIKitDriver` in the host's test
application, one test for each family of cases in `UIKitConformanceTests`,
their verdicts held to `lib/StateUI/exports/marks/uikit`.

## An application of tests

A view stands in a window only in an application's process, and a window only
in a scene iOS connected. So the host's tests are an application of their
own, which `test-uikit.sh` builds, installs on a simulator and starts: once
its first scene connects and stands in front, the runner reads every test case of its own binary
by name - a class of the whole process may be no object at all - and runs
each test in a turn of the main run loop of its own, saying each as it ends.
A turn of the run loop, not a block on the main queue: a test turns the run
loop to let what it waits for arrive, and a handler resumed on the main actor
comes back on the main queue, which runs nothing while one of its own blocks
does. The process ends with the report the script reads.

Every test's windows stand in that one scene; a host a test ends takes its
windows out of the scene and leaves the scene for the next. XCTest is the
simulator platform's own, read where it stands. An application on the
simulator reads and writes the Mac's files where they are, so a run holds
`exports` to what it says, or writes it there with
`STATEUI_UPDATE_EXPORTS=1`, which the script hands the application.

## What the driver does

A user's act goes through the path UIKit's own input takes into the host: a
button's primary action, and a check box's; a switch turned and its
value-changed event sent; a slider taken, moved and let go; a stepper's step,
which at an end of its range - where UIKit turns the button off - does
nothing; a menu's choice; a date or a time picked. Typed words first ask the
view's delegate, as a key does, then replace the words and send the change;
the return key asks the field's delegate.

UIKit makes no touch a test can send. A finger's and a pointer's acts are
handed to the view's listening as its recognizers hand them to their target:
a recognizer of the kind UIKit makes, in the state the act puts it in, its
touch at the act's point - a run of taps, a pan from the middle in two moves,
a pinch, a press put down, dragged and lifted, the pointer over the view and
leaving it. A view that does not listen hears nothing, as UIKit sends it
nothing.

## What the driver reads

A member's value is read from the view UIKit holds - a label's and a field's
words, caret and selection, a button's title, a toggle's state, a slider's
and a stepper's value and range, a picker's choices, a view's hiding, alpha
and a control's enabled state, a button's and a label's padding, its
transform as its layer holds it, what VoiceOver meets, a control's font and
colours, a menu entry's and a bar item's action - never from what the host
last wrote. A text view takes input while the user can edit or select it,
and is read only while they can select it and not edit it. A colour at a point is read from the screen: the view drawn as the
screen shows it into a bitmap in sRGB. Whether a touch reaches a view is the
window's own hit testing at that point.

A layout's box and a shape's paint are layers UIKit holds: a box's fill and
outline layers, a shape's colour layers cut by the shape layers that draw its
line, whose dashes UIKit keeps in points and the driver reads back in the
line's widths. A shape given no stroke draws no line, and holds none of it.
A button's box, icon and breaking are its configuration's. What UIKit holds
none of - a shape's figure placed and moved into its path, a layout's outline
held as a path, where StateUI's layout places the children, what StateUI
measures - does not apply here, its effect proven by another case.

## What goes past UIKit

UIKit lets a test send no touch and moves no scene, so the driver hands some
acts to the host's own entry: the gestures and the pointer to the view's
listening as the recognizers' states, a drag between views to the
interactions' handlers, a picker's choice, a question's answer and a file
dialog's to the host, a scene's phases to the renderer, and a web
view's end of content to its delegate. A few reads are the host's own too: a
check's and a picker's state, the menu bar's entries, a question's captions,
the document picker it presented, what it announced and launched, and a
transform checked against the layer it composed. The
driver names each (`byHost`), and a member a case proves only through them is
the host's own - ✓ - never ✅.
