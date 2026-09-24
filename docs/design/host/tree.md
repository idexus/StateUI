# The mounted tree

How a runtime holds the description it shows: one mounted element per
described node, each with a native half that its toolkit writes. [The
runtime](runtime.md) draws where the tree sits in a turn and a frame.

## The mounted tree

```text
  MountedTree                         the root, the numbers, the patch's clock
    |
    MountedElement  (host layer)      key, type, children,
    |   |                             described properties, bound states,
    |   |                             event handlers, layout motion,
    |   |                             drift, leaving, the frame walk
    |   |
    |   native: NativeElement  ---->  AppKitElement (toolkit half)
    |                                  NSView, constraints, gestures,
    |                                  accessibility, menus, pages
    MountedElement ...
```

`MountedTree` applies the root patch of each message and owns what every
element shares: the line to the core, the patch intake it tells of a drift,
the state channels the elements wear, and the property and layout animations.
Every element of one message takes its animations' start from one time, the
message's, so a patch that animates many properties starts them together.

A `MountedElement` is one live instance of a described node. It keeps the
node's key and type, its properties, bound states and handlers, and its
children in order. It applies a patch in one fixed order: the standing values
of what changes are read first; then the properties, events and bindings;
then the children, by key; then each changed property's animation starts, from
where it stands; and last its native half presents it all. A child a sparse
patch names but the element does not hold, or holds as another type, is a
drift: it is refused, and nothing is mounted from it.

## The native half

A toolkit writes only what the toolkit has: an element's view and what hangs
off it. `NativeElement` is that half's whole contract with the tree - it hears
that a patch is about to apply and that it applied, presents a frame's changed
properties, arranges children, reports where a property stands natively and
whether the toolkit animates it, and lets go when the element leaves. The
element owns its native half; the half refers back without owning, so it can
never outlive the element. Anything that keeps an element beyond the tree -
a window's shown page, a sheet - holds the element, never the native half.

## Standing values

An animation starts where the value stands, never where the tree last said it
was. A running animation's value comes first; then what the toolkit reads off
the control - a window's live frame, a slider's position, a view's opacity;
then the bound or described value. Where none exists but the toolkit animates
the property, the property's resting value is the start: no margin, no turn,
a scale of one, a corner radius of the target's shape.

## Leaving

An element leaves by every road out of the tree - dropped from an arrangement,
replaced, a new root - and everything under it leaves with it. It lets go of the states it wears, so a channel's
last wearer takes the channel with it once it lands; its property and layout
animations end; and its native half detaches what it attached outside the
tree: observers, recognizers, a scroller's hold on the frame clock. Nothing
keeps a control alive after the tree drops it.

## A radio group

A radio button checked by the user unchecks the others of its choice, and
each of those reports that it is off. Which they are is the tree's to say,
the same on every host: the radio buttons of its `groupName` anywhere in its
window, or, where it names no group, the radio buttons beside it under the
same parent. A native group of the platform's is not used: it holds only its
own direct children, while StateUI's may stand anywhere in a window's
layouts.
