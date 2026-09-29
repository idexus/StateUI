# Registrations on AppKit

The AppKit half realizes the element contracts through the core's registry:
how each element's view is made, which of its members the view takes, and
what it reports. `AppKitRegistrations` builds the registry once, one family a
file - indicators, toggles, values, pickers, fields, shapes, buttons,
pictures, drawing, layouts, presentation - and the members every element
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
the room, the drawing over it, what assistive technology meets and the
user's input; the host adds one call per member of its own. Each member is
declared with the type it carries, so the compiler still refuses a wrong
tier where a list of names would pass quietly.

## What a declaration leaves out

A declaration says what the host does, not what a tier offers:

- `panTouchCount` is recorded partial: the host layer hears a one-finger pan
  only, which only a record with its note can say.
- `allowDrop`, `canDrag` and `dragText` are absent: AppKit realizes no
  dragging.
- `clipsContent` and `avoidsSafeArea` are absent: this host reads neither.
- `background` and `isEnabled` are taken by the registrations of the controls
  that have them. A background is a partial realization on this host, which
  only a record with its note can say.

## The scroll view

The host makes the scroll view itself: it reports through a user transaction
and asks the host for display frames, and neither is an event of its
contract, so its registration takes the members alone. Its offset is written
only where the tree moved it - see [scrolling](input.md#scrolling).
