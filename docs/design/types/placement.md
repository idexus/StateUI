# Placement

A `MotionLayout` puts each of its views where an application's arithmetic
says. A `Placement` is that answer for one view, and a `PlacedRun` the
answer for the whole run, which the host is handed typed.

## Where one view goes

A placement is a rectangle, a transform about the view's center, an opacity,
a shade and a z-index. Every field but the rectangle defaults to the view as
it was drawn, so a layout that only positions its views says
`Placement(rect)`. The type is the author's; the boundary's is
`HostPlacement`, the same fact as numbers a toolkit sets.

## Written onto the placed view

Each field is drawn onto the container the layout wraps the view in, over
what the view's own properties say. A view inside a `MotionLayout` is turned,
scaled and faded by its placement, and what the closure that builds it writes
stays its own: the placement composes with it and never overwrites it.

## One picture on every platform

Every field means the same picture on every platform, and that decides the
list. A move, a turn in the plane of the screen and a change of size are the
same arithmetic wherever they are drawn, about the view's own center. A turn
out of that plane is not: `rotationX` and `rotationY` are projected through a
camera each platform chooses for itself, so one run of cards at one angle
turns away on one platform and tilts and shifts on another. They are not
fields; a card turned away is a `scaleX` of `cos(angle)`, which is what
`.turn(_:)` writes and which is exact everywhere.

The pivot is not a field either. A turn and a scale are centered on the view,
which is what makes them the same everywhere, and moving that center is
worked out from the view's own size, read when the property is written,
before this layout has given the view one. A pivot goes on the view in the
closure that builds it, where it is a constant.

## Shade and opacity

A view faded to a half shows whatever is behind it, which in a run of
overlapping cards is the next card rather than the page. A shade darkens what
is there instead. `shade` is the opacity of a view the application gives the
layout with `.shade(_:)`, drawn over every placed view; a layout with no
shade wears none of it, whatever the arithmetic answers. The shade is a view
rather than a color because only its author knows the shape it must match:
a card with rounded corners needs a shade with the same corners.

## Drawing order as ranks

A z-index says which view is drawn over which, and nothing else, so its
order is the whole of its meaning. Arithmetic over a value the user is
moving answers a new number on every report, while the order it expresses
changes only when two views swap, and a platform given a new z-index puts
its children in order again, which is a whole measure of the layout. So a
run replaces each z-index with its rank, back to front, and a rank changes
only when the picture does. Equal numbers keep the order the views stand in.
A z-index does not animate: an order has no half-way.

## A run lands as written

A run carries no law: it lands as written. Placements are worked out - from
the room, the phase, a finger - and a value worked out is written at once
(journeys.md, writing the parts); what travels is the phase they are worked
out from, whose journey a host walks. A host walking places from one to the
next draws a straight line: a chord across a ring, and for a whole turn
nothing at all.

## A run as the host is handed it

A run reaches the host typed, through the layout's program
([a layout's program](../core/layout-program.md)): one `HostPlacement` a
view, in the views' order - the rectangle, the move, the turn, the two
scales, the opacity, the rank and the shade as numbers a toolkit sets. No
state carries a run and nothing encodes it: the host holds the views
already, so there is no identity to carry, no property to name and nothing
to diff. The host finds a shade as a placed view's second child, so a
layout with no shade draws none, whatever number its run holds for it. A
run of no placements is an empty run - what a layout whose room is not
measured answers - so a layout with nothing on it yet is a picture rather
than a failure.

The trap was a run as lanes on a state: twelve numbers a view, read by
stride, with a dirty word that ran out at the sixth view. It crossed what
both sides already held typed, and made a placement a value a state could
carry, which nothing ever asked of it.
