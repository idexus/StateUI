# Input on AppKit

How the AppKit half meets the user's hand: which view a click reaches, where
the keyboard focus is, and how a scroller's movement reaches the core. The
platform owns each gesture; the host only says what StateUI needs to know.

## Hit testing

AppKit finds the deepest native view under a point through `hitTest(_:)`.
StateUI's input transparency is decided there, by `AppKitHitTestView`, the
surface every StateUI container stands on. A transparent layout removes its
whole subtree from the search; with cascading off, it removes only itself and
keeps its interactive children reachable.

A native control - a button, a field, a slider - is no such surface, and
AppKit holds no flag on a view that takes it out of the search. So a control
that ignores input is kept in a weak set, and the layout holding it, finding a
point inside it, passes over it to what stands behind it: its other children,
or the layout itself.

An element that answers a tap is pressed by assistive technology too: its
press action runs the same handler a click runs, so VoiceOver and automation
reach it through the native accessibility press rather than a synthetic
click.

## A disabled view

A control the tree disables, or one in a disabled branch, is an `NSControl`
with `isEnabled` off, as `presented(_:)` gives it. A view that is no control
keeps its place and takes the press, but the host layer hears nothing of the
hand in it; it tells assistive technology it answers nothing
(`setAccessibilityEnabled(false)`), what the driver reads back.

## The first click

An element that answers a tap takes the first click into an inactive window,
as a native control does, so a row opens wherever it is clicked rather than
only on its text. An element that answers nothing leaves that click to
activate the window.

## Focus

The keyboard focus is the platform's. It moves on a click, a Tab, a Return
and whenever AppKit takes it away, so StateUI never mirrors it as state. The
host needs two answers, and asks the window for both at the moment they
matter:

- which view inside an element takes the keyboard: the element's view where it
  does, or the first view within it that does - a text field's own field, not
  the box it stands in;
- whether a window's first responder is inside an element. A text field's
  field editor is a separate view the window lends the field, so it counts as
  the field it edits.

Tab and Shift-Tab go from view to view in the order they stand on screen. A
window and a sheet work that loop out themselves
(`autorecalculatesKeyViewLoop`): StateUI's views are made and placed long
after the window, and a window keeping the loop it was given leaves a field
alone in its own - Tab then selects the field's words instead of moving on.

## Scrolling

The scrolling is the platform's, and the host layer's `ScrollMovement` says
where a movement went and when it is over
([a scroller's movement](../../host/runtime.md#a-scrollers-movement)). AppKit
tells it a live scroll's beginning and end - the end with its momentum run
out, so the movement rests there - and every move of the clip view.

```text
  AppKit moves the clip view            (inside its own frame step)
        |
        v
  ScrollMovement.userMoved              joins the move before it: one move
        |                               per frame, from where it began
        v
  the display's next frame              frame(now:) hands the reports over:
        |                               moved(from:to:), then rested
        v
  the scroll view's element             the offset state and the events
```

A wheel's click is a movement no live scroll brackets, and rests once the
offset has stood still.

The offset is written to the scroller only where the tree moved it: the
user's own scrolling comes back as the state it wrote, and putting the clip
view back where it already stands would interrupt the platform's scroll
mid-gesture.

## What the user does

What the user does with the pointer and the trackpad AppKit's own recognizers
hear, and each tells the host layer what it heard - never an event: a click
with its place in a quick run of clicks, a press dragged with its phase and
how far it has come, a pinch's step, the pointer's coming, moving, pressing,
letting go and leaving - each measured from the view's top left, as every
host measures it. Which of them an element listens for, how many clicks make
its tap, the states a drag carries and whether a drag that ended was a swipe
are the host layer's (`MountedElement.hearing`, `hear`). AppKit drags with one
pointer: an element asking a pan of more gets no drag recognizer.

## A drag between views

A view that can be dragged holds a pan recognizer of its own: once the press
has moved past AppKit's distance it begins AppKit's dragging session,
carrying the view's words as a string, its picture the view as it shows,
and lets the press go to the session; the session tells the view it started
and, wherever it ended, that it ended. A view taking drops registers
nothing itself - a layout replaces its subviews as it arranges them, and a
control is AppKit's own class. The window's root takes every drag that
carries words - the window's content view, or a sheet's page - and finds the
view under it as AppKit finds a destination: its hit test, then that view's
ancestors, among the views whose elements take drops, read as the drag
comes. The view under the drag hears it come and go, and the drop with its
words; the host layer's rule makes over once and no leave after a drop. The
root takes files dragged from the system too: a drag holding file addresses
finds a view taking files, and its drop hands over each file's path.

## Where a view stands

A view whose frame the tree reads is followed by the host layer
(`FrameFollowers`): AppKit tells it only that something moved - the view, or
any ancestor up to its window's content, watched through their frame and
bounds notifications, a scroller's clip among them - and the host layer asks
each follower on the display's next frame, in the order they were made, as one
of the user's transactions. The view says its place in its parent, its corner
in its window and from the window's content, each from the top left. It says
nothing while it stands in no window or before a layout placed it - StateUI's,
or AppKit's giving it a size: a view that joins a shown page meets a display
frame before its layout, and its first report is where it is laid out.

