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
user's: the host makes its windows and never orders them in, and so no window
stands shown or hidden for the driver to read. What AppKit tells a window's
delegate as the window comes to the front, goes behind another application,
is minimized and comes back - `didBecomeKey`, `didResignKey`,
`didMiniaturize`, `didDeminiaturize` - the driver posts on the window itself,
where the delegate hears it as it hears AppKit; another application in front
is every window's `didResignKey`. A window closed by the user is the window's
own `close`.

No display cycle lays out a window off the screen, so the driver lays each
window out at every step, as the cycle would, and before every act of the
user's: a user acts on a window they see, laid out.

A case's next launch is a launch: the windows the last host left open, each
as its delegate encoded it, go through the restoration class as the system
hands them back, before the new host finishes launching, and stand where
they stood, as the system puts them. The driver's hosts
keep their values in preferences of their own, which a case's first launch
finds empty.

## Parts

A family runs as one test, and the longest - a visual element's, a view's, a
shape's, each a case for every element wearing the tier - in parts of some ten
seconds, each a test of its own writing its own file of verdicts, which the
dictionary reads together. A part runs alone by its name (`swift test
--filter AppKitConformanceTests/testVisualElement5`), and the parts run side by
side under `swift test --parallel`, the whole suite in some four minutes where
one process takes nine.

## Pictures

Every host's suite holds the two pictures the cases name, 6 by 4 and 40 by 20,
in `Tests/Resources/Images`; the driver's host reads its resources there.

## What the driver reads

A member's value is read from the control AppKit holds - a switch's state, a
slider's range, a field's words, a view's alpha, a control's font and its
words' colour, the tint a checkbox, a picker or a slider shows, what its
accessibility object tells assistive technology, the colour its layer paints
behind it, a menu entry's NSMenuItem and a toolbar item's NSToolbarItem -
never from what the host last wrote. A
view's transform is the drawing's where the view's layer holds that drawing
now, and none where AppKit holds another. A colour is read from the view
displayed into a context of sRGB, which StateUI's colours are: a bitmap in
the screen's own space holds the screen's numbers. A heading's level stays
unread, with why: AppKit marks a heading, not its level. What the driver cannot read or do yet it says with why, and the
case stays empty in AppKit's column rather than failing.

A label's words are read from the text field it lays out, a field's from its
text field, an editor's from its text view; a button's and a scroller's
outline from their layer, which holds the radius it draws - at most half the
box's shorter side, where a radius past that is not read. What AppKit holds
none of - what StateUI draws in a view's `draw(_:)`, where StateUI's layout
places the children, what StateUI measures and what the host cuts - does not
apply here, its effect proven by another case. A field's spelling and caret
live on the editor AppKit lends the field while the user edits it, and are
not read.

## What goes past AppKit

A window the driver never orders in takes no synthetic event, so the driver
hands some acts to the host's own entry: the gestures and the pointer to the
host's recognizers, a button's press and a canvas's to their handlers, a
picker's menu, choice and date to the host's own change, a scroll to the
host's movement, a question's answer and a file dialog's, a drag between views
to its source and the window's drop routing, the toolbar's and a sheet's way
back, and a window's phases as the notifications AppKit would post.
A few reads are the host's own too: the tab it chose, a spinner's flag, a
transform checked against the layer it composed, the restoration record, the
menu bar's items as built at the read, the captions of a question, the panel
it holds, what it announced and what it launched. The driver
names each (`byHost`), and a member a case proves only through them is the
host's own - ✓ - never ✅.
