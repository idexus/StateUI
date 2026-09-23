# Lists

A list describes only the items in view. `ItemsView` is a composition over
controls that already cross to a host - a `ScrollView`, an `AbsoluteLayout`,
the author's item views - and puts nothing of its own on the wire: no node
type, no host realization, no fixture. It is compiled for the MAUI host alone.

## ItemsView describes only the items in view

```text
  ScrollView (orientation, offset carried as a state, aim)
   └── [header]
       AbsoluteLayout  length = the sum over the groups   (recycling)
        ├── slot k      Rect(0, start(k), width, length(k))  ─┐ the window: the slot
        ├── slot k+1                                           │ at the top, the ones
        └── …                                                  ┘ that fit, 6 either side
       [footer]
```

The layout's length is computed - the count times one measured item, summed
over the groups - so the scroller knows how far it goes before a single item
is described. The scroll position, the measured viewport and that length say
which slots are in view; those and a margin of six either side are the only
ones described, built and sent. Every slot is placed by its number rather than
by what stands before it.

What an item costs: an item that scrolls out of the window leaves the tree and
takes its own `@State` with it, while the host keeps its control for the next
item of the same shape. What must outlive the window - a half-typed edit,
whether an item is expanded - belongs in the page, keyed by the item.

## Two paths

Each path does what it is for. The offset is a host-carried state: the host
writes the user's scrolling into it on its own frames, and nothing is described
for it. An engine following it works out which slot is at the top and writes
that into an ordinary state only when it changes, so a fling renders once per
item crossed and never once per frame. Which items exist is a structural
decision, and the body reads it. The engine also runs once after every render,
so a run measured anew puts the window where the offset says.

Asking whether the user has reached the end happens on the description path,
when the slot at the top changes: an engine runs inside a frame and awaits
nothing.

## Groups are slots

A grouped list is a run of slots: a group's header, its items, its footer, the
next group's header. Each kind is measured once, so where any slot sits is a
sum over the groups before it, worked out once per render over the groups
rather than the items, and a slot is found by a binary search over the groups -
a hundred groups are seven comparisons. A group's header and footer are slots
like the items, so every group's header has one length and so does every
footer.

An item's identity is written under its group's name, or its group's position
where the group has none, so two groups may hold equal items; a list of one
group prefixes nothing.

## Measuring

`.uniform`, the default, measures the first item placed and gives every other
item its length, which is what lets the list know how long it is without
describing anything: where a slot sits is one multiplication, and a hundred
thousand items cost what ten do. `.itemSize(_:)` states the length instead,
known before anything is drawn.

`.individual` measures every item, filed by its identity - never by its
position, which an insertion at the top would shift, handing every item below
its neighbour's length. The run is worked out item by item, one number per
slot summed once as the plan is built, so it suits tens or hundreds of items.
An item never in view is worth an estimate; the items before the user have
been measured, so nothing in view shifts as the rest of the run is worked out.

Until a kind is measured, a slot is given a provisional length for one render,
and the slots placed measure themselves: the window is then the first slot of
each unmeasured kind, wherever it falls, since a footer may be a thousand items
down and the arithmetic cannot settle without it. The scroller's size is kept
as a width and a height rather than along and across the axis, because the axis
can change while the frame does not. A list turned round forgets every length
it measured - a length along one axis is none along the other - and measures
again.

## The window

The window is the slot at the top, the slots that fit after it, and a margin of
six either side, so an ordinary flick finds its slots already there: a slot is
cheap here and a blank one is not. How many fit is counted off the shortest
slot the run has, so the answer is never short - a window a slot too small is a
band of nothing at the end of the view. Until the scroller reports its size,
the window is drawn against the screen's length: no list is longer than the
window it is in, and the scroller's report can arrive after the slots are
placed.

A list must be bounded along the way it scrolls. In a stack, a scroller asked
how long it wants to be answers with its whole content, so the list is laid out
as long as its run, describes every slot, and has nothing left to scroll. The
list says so with a complaint rather than refusing, and only where the run is
longer than a screen, since a short list in a tall box is ordinary.

## Items arrive

The list's own numbers arrive rather than animate: every length it states
answers a measurement, and an offset written with no motion of its own is a
place, not an animation. An item's root is given `Motion.none` unless its
author wrote a motion there, because the list hands its controls round: the
item scrolling into view is very often the control that just left the other
end, wearing another item's words and widths, and a motion on its root would
move its insides across the screen while the user scrolls. A motion is per node
and never inherited, so what the author wrote inside an item still animates.

## Recycling

`AbsoluteLayout.recycling()` marks a layout's children as rows: interchangeable
subtrees, a few described at a time out of many. The host keeps the control of
a row that scrolls away and gives it to the next row of the same shape. A shape
is a number over a subtree's types, property keys and event keys with the
values left out (`Recycling.swift`), so two rows share a shape
exactly when they name the same properties on the same controls in the same
places, and an adopted control is given a value for every property it carries.

The modifier stays internal. What it promises is that any child of the layout
could stand where any other of the same shape stands, which is true of a list's
rows and a gallery's cards by construction and is not something an application
can be asked to be sure of.

## End reached

`onEndReached(within:)` counts items after the last one in view - a group's
header and footer are no items. The question is one closure, asked in every
place it can become true: the slot at the top changing, the scroller measured,
and the run measured or grown. A batch shorter than the view leaves nothing to
scroll, so the list asks again as it grows, until it outgrows the view. It runs
more than once while the user stays near the end, so the handler guards on what
it has already asked for.

## Selection

The binding's type says how much may be chosen - an optional identity for one,
a `Set` for many - so there is no mode beside it to disagree with. A tap on the
chosen item clears it; among many, a tap adds or removes that item alone. A
list lent no binding answers no tap, and what a chosen item looks like is the
template's, reading the state the binding writes.
