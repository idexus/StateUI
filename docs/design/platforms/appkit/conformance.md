# Conformance on AppKit

How the conformance suite drives AppKit: `AppKitDriver` in the host's test
target, one test for each family of cases in `AppKitConformanceTests`.

## What the driver does

A user's act goes through the path AppKit's own input takes into the host: a
button's, a check box's and a radio button's `performClick`, a switch's
accessibility press, a slider's value and then its action, a stepper's value
one increment on within its range and then its action - what a click on
either arrow does - a picker's item chosen, and a field's or an editor's
words typed through the editor AppKit gives the view holding the keyboard, so
what the field reports is what a user's typing reports. Return in a field is
the field editor's newline, which ends its editing as the keyboard's Return
does.

## Windows

The driver shows no window on the machine's screen, so a run never takes the
user's: the host makes its windows and never orders them in. What AppKit tells
a window's delegate as the window comes to the front, goes behind another
application, is minimized and comes back - `didBecomeKey`, `didResignKey`,
`didMiniaturize`, `didDeminiaturize` - the driver posts on the window itself,
where the delegate hears it as it hears AppKit, and the application's being
put behind another is told as AppKit's application delegate tells it. A
window closed by the user is the window's own `close`.

## Pictures

Every host's suite holds the two pictures the cases name, 6 by 4 and 40 by 20,
in `Tests/Resources/Images`; the driver's host reads its resources there.

## What the driver reads

A member's value is read from the control AppKit holds - a switch's state, a
slider's range, a field's words, a view's alpha - never from what the host
last wrote. What the driver cannot read or do yet it says with why, and the
case stays empty in AppKit's column rather than failing.
