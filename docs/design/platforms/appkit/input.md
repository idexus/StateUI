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

An element that answers a tap is pressed by assistive technology too: its
press action runs the same handler a click runs, so VoiceOver and automation
reach it through the native accessibility press rather than a synthetic
click.

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
