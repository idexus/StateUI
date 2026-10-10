# Registrations on AppKit

The AppKit half realizes the element contracts through the core's registry:
how each element's view is made, which of its members the view takes, and
what it reports. `AppKitRegistrations` builds the registry once, one family a
file - indicators, items, maps, web, toggles, values, pickers, fields,
shapes, buttons, pictures, drawing, layouts, presentation - and the members every element
shares. An element no registration answers is still made by `AppKitElement`.

## Shared members

Some members are realized around every view rather than inside a
registration: the room a view is given, how it is drawn and turned, what a
screen reader says about it, and the gestures it answers. They are said with
the contracts' own members, so the compiler refuses a member of a tier an
element cannot wear - the whole advantage of declaring shared machinery this
way rather than as a list of names. Each reaches exactly the elements wearing
the contract that declares it, so `Layout`'s members go to the layouts alone.

What every host realizes by the host layer's rules is declared by the layer's
groups ([what every element realizes](../../host/tree.md#what-every-element-realizes)):
the room, the drawing over it, what assistive technology meets, the user's
input, a drag between views and files dropped on a view; the host adds one
call per member of its own. Each member is
declared with the type it carries, so the compiler still refuses a wrong
tier where a list of names would pass quietly.

## A background

A view's background is its layer's colour, a rectangle under its whole frame,
unless its registration takes the background itself
(`drawOwnBackground`): a text field fills its own field, a button its own
face, a colour box its own box. A text field given a colour drops AppKit's
bezel, which on macOS 26 draws its own ground over any colour, and stands in
the bezel's rounded shape, filled with it; one given none keeps the rounded
bezel, with its own ground and its words set in from the edge. A border and a
bezel exclude each other: `isBordered = false` said after `isBezeled = true`
takes the bezel away, leaving bare words on whatever lies behind, so the
border is said first. A search field given a colour stands in its bezel's
capsule, filled with it: AppKit's bezel ignores `backgroundColor`, so the
field drops the bezel and its cell sets the magnifier, the words and the
cancel button in as the bezel does, across the middle of its height - and hands
the editor that room, which AppKit lays over a bezel-less field's whole
frame. Each field's
ring, while it holds the keyboard, goes round the shape it stands in
(`drawFocusRingMask`). A text editor has no bezel of its own: its scroller stands
rounded as a field does, borderless, its words set in from the edge.

## What a declaration leaves out

A declaration says what the host does, not what a tier offers:

- `panTouchCount` is recorded partial: the host layer hears a one-finger pan
  only, which only a record with its note can say.
- `avoidsSafeArea` is absent: this host does not read it.
- `background` is taken by the registrations of the controls that have it. A
  background is a partial realization on this host, which only a record with
  its note can say.

## The scroll view

The host makes the scroll view itself: it reports through a user transaction
and asks the host for display frames, and neither is an event of its
contract, so its registration takes the members alone. Its offset is written
only where the tree moved it - see [scrolling](input.md#scrolling).
