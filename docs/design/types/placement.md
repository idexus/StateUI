# Placement

A `PlacedLayout` puts each of its views where an application's arithmetic
says. A `Placement` is that answer for one view, a `PlacedRun` the answer for
the whole run, and `PackedPlacement` the same answer as the numbers a host
reads.

## Where one view goes

A placement is a rectangle, a transform about the view's centre, an opacity,
a shade and a z-index. Every field but the rectangle defaults to the view as
it was drawn, so a layout that only positions its views says
`Placement(rect)`. The type is the author's; the twelve numbers are the
boundary's. Both live in one file because they are the same fact, what one
view's place is, said once for each.

## Written onto the placed view

Each field is a property of the view being placed, written onto it by the
layout. A view inside a `PlacedLayout` is therefore turned, scaled and faded
by its placement, not in the closure that builds it: the placement would
overwrite what the closure wrote.

## One picture on every platform

Every field means the same picture on every platform, and that decides the
list. A move, a turn in the plane of the screen and a change of size are the
same arithmetic wherever they are drawn, about the view's own centre. A turn
out of that plane is not: `rotationX` and `rotationY` are projected through a
camera each platform chooses for itself, so one run of cards at one angle
turns away on one platform and tilts and shifts on another. They are not
fields; a card turned away is a `scaleX` of `cos(angle)`, which is what
`.turn(_:)` writes and which is exact everywhere.

The pivot is not a field either. A turn and a scale are centred on the view,
which is what makes them the same everywhere, and moving that centre is
worked out from the view's own size, read when the property is written,
before this layout has given the view one. A pivot goes on the view in the
closure that builds it, where it is a constant.

## Shade and opacity

A view faded to a half shows whatever is behind it, which in a run of
overlapping cards is the next card rather than the page. A shade darkens what
is there instead. `shade` is the opacity of a view the application gives the
layout with `.shade(_:)`, drawn over every placed view; a layout with no
shade wears none of it, whatever the arithmetic answers. The shade is a view
rather than a colour because only its author knows the shape it must match:
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

## A motion per write

A `PlacedRun` carries its own motion, per write, which is what a layout
followed by a finger needs. The run is written at once (`.none`, the
default) while a hand is moving it, since the next frame replaces whatever
an animation would reach for, and animates when the shape of the layout
changes. A write made during an animation bends it rather than starting it
again, so a finger moving the cards while they cross does not restart the
crossing. `.inherited` uses the layout's own `.motion`.

## Twelve numbers a view

A placement crosses as twelve numbers, in one order, and a run as each
view's twelve followed by its motion's three.

```text
  x  y  width  height    translationX  translationY  rotation  scaleX  scaleY    opacity  zIndex  shade
  0  1  2      3         4             5             6         7       8         9        10      11
```

The motion comes last, so a view's numbers always start at `12 × index`,
which lets a host read one view's place by stride and know which view a
changed lane belongs to. A state's dirty word has a bit per lane and runs
out at lane 63, so a run says exactly which of its first five views moved
and reports the rest together. That costs nothing: a view given the place it
already has is skipped before anything is written.

`PackedPlacement` writes the same twelve numbers straight into a buffer the
host reads by stride, on the platform's own frames: there is no identity to
carry, no property to name and nothing to diff, since the host holds the
views already. A layout with no shade writes -1 as the shade, a number no
opacity can be, which tells the host to look for no shade view. An empty
image is an empty run - what a state never written stands at - so a layout
with nothing on it yet is a picture rather than a failure.
