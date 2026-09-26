# Conformance on UIKit

How the conformance suite drives UIKit: `UIKitDriver` in the host's test
application, one test for each family of cases in `UIKitConformanceTests`,
their verdicts held to `exports/marks/uikit`.

## An application of tests

A view stands in a window only in an application's process, and a window only
in a scene iOS connected. So the host's tests are an application of their
own, which `test-uikit.sh` builds, installs on a simulator and starts: once
its first scene connects, the runner reads every test case of its own binary
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
button's primary action, a field's words replaced and its editing-changed
event sent, as a key sends it, and the return key's question to the field's
delegate.

## What the driver reads

A member's value is read from the view UIKit holds - a label's and a field's
words, a button's title, a view's hiding, alpha and a control's enabled
state - never from what the host last wrote.
