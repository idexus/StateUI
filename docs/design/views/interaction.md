# Interaction

An `Interaction` says what the user's hand moves on a view, and how. It is a
value written with the view - `.interaction(_:)` - and read by the view where
it stands: making one recognizes nothing, reserves nothing and starts no
clock.

```text
  Interaction ── leaves, in written order
   └── leaf ── state      whose number the hand moves (the identity of its storage)
               axis       which number of it (a key path)
               input      what of the hand moves it        InteractionInput
               range      how far the hand may take it     none: no end
               snaps      where it may rest                AxisValues, none: anywhere
               periodic   whether it comes round
               reversed   which way it grows
               release    how it goes on let go            InteractionRelease
               programWrites  what a write does under the hand   InteractionProgramWrites
```

## One declaration

One `.interaction(_:)` says the whole of a view's interaction: said again it
takes the other's place, and nil takes it away. Several values moved at once
are one interaction, `Interaction.simultaneous(_:)`, so what moves together
is written together and a view never holds two declarations that could
disagree.

Every method answers a copy. `range`, `snaps`, `periodic` and `reversed` are
one value's own, so said of several at once they are refused and said;
`release` and `programWrites` said of several are given to each, which is how
values let go together are written to go on by one law.

Where the hand is declared apart from the mapping, two things that were one
declaration are two: how far the hand may take a value (the interaction's
`range`) and how far a layout's mapping runs (`axis(_:range:…)`). They may
differ - the program writes a value anywhere, and a mapping covers what the
program may write.

## The input

`InteractionInput` names what of the hand moves the value:

```text
  .translation(way, unit:)   a finger or a pointer dragged, a trackpad's two fingers, a wheel
  .swipe(way, unit:)         the same hand, one snap at most a hand
  .magnification             two fingers spreading: the value multiplied
  .rotation(degreesPerUnit:) two fingers turning: a unit every so many degrees
```

The way a hand moves a value is an `Orientation`, and names the way alone. A
value grows as the hand moves right or down, and as the fingers turn
clockwise; `reversed(true)` turns it - the hand's move and its speed alike,
and a wheel's notch with them. A row of cards whose growing number moves
them left is reversed; a panel dragged by its edge is not.

An input given points or degrees a unit that are not above nought is kept as
a complaint in the input itself and said by the view that reads it: a value
is a value, and has nowhere to speak from until it is worn.

## The unit

`InteractionUnit` says how far the hand travels for one unit of the value:
so many points, the room's length along the hand's way, or as far as the
view drawn in front moves for a unit. A point is the unit unless said: a
value moved by a hand with no layout to measure is in points.

`.frontItem` is a motion layout's to measure
([the hand](motion-layout.md#the-hand)): the host asks the layout's own
arithmetic how far its front view goes for a unit where the run stands.

## Letting go

`InteractionRelease` says how the value goes on once the hand lets go:

```text
  .projected(motion)   thrown on: where the throw would end, the snap nearest there
  .nearest(motion)     onto the value it may rest at nearest where the hand left it
  .stay                where the hand left it, with no travel
```

Whichever is said, the value comes to rest inside its range, on a snap where
it has snaps. A throw is `.projected`'s alone: under `.nearest` and `.stay`
the hand's speed chooses nothing. Thrown on unless said, as a glide of eight
tenths of a second at the longest.

Values let go together go on as one journey of their state, under one law:
a throw's where one is thrown, else the approach of the longest way
([letting go](../host/interaction.md#letting-go)). A value that stays is set
where it rests before the others set out, so it travels nowhere while they
do.

## A write of the program

`InteractionProgramWrites` says what a write of the program does to a value
the hand holds: `.interrupt`, unless said, ends the hand's gesture there and
the value travels where the program sent it from under the hand;
`.deferLatest` keeps the value under the hand - the state going where the
program sent it at once - and sends it there once the hand lets go. A write
of another number of the same state meets no hand at all
([a write of the program](../host/interaction.md#a-write-of-the-program)).
The range and the snaps are the hand's alone: the program writes a value
anywhere.

## On a motion layout

A motion layout reads the interaction as it is described
(`MotionLayout.worked`), together with its axes' mappings, into one record an
axis the run works on (`Hand`): what moves the axis, the hand's range and
snaps, its period, its way and its release from the interaction; the
keyframes, the mapping's own range and the segments from `axis(_:range:…)`.
An axis the interaction moves needs no mapping, and a mapped axis no
interaction.

A value of the interaction is one of the layout's own parameters: its state
is told by the identity of the storage the layout's `parameters:` binding
stands on, and its axis is one of the parameters' `axes`. The layout writes
the values that stand onto its element as the program the host answers the
hand by (`MotionLayoutContract.interaction`), and keeps of each only what its
own arithmetic reads: which way a hand moves it, for the front view's unit,
and its release, for a view the hand throws.

## What the host is handed

The differ makes the declaration plain values (`Interaction.program`,
`HostInteractionProgram`): each value its state's number - its channel - the
axis's place among the state's numbers, the input with its unit, the ends
(an infinity for none), the snaps, whether it comes round, which way it
grows, the release and what a write does under the hand. Snaps between the
ends of a range are listed with the ends; with no range, a step is handed
as a step (`.every`), worked out by the host and never listed, and a list
as written. A value that is no number of its state, or whose state the host
carries as no journey, is handed as nothing.

`HostPatch.interaction` carries it: `.replace` where the values changed,
`.clear` where the hand moves nothing any more, nil for no change. The
program holds no closure, so it is compared as it is (`RenderedNode.interaction`)
and one described again alike is not told again - a hand holding a value
through a render stays where it is.

## What is refused

A declaration that does not stand moves nothing and is said (`complain`),
never mended into something near it:

- a value that is no axis of the layout's parameters, or of another state;
- two values moving one number - both, as neither is the one the author
  meant;
- a range with no end; a magnification's range reaching nought, or told to
  come round;
- coming round with no range of some length to come round over;
- a swipe given no snaps - it goes a snap a hand, and has none to go to;
- the ends of a range to rest at (`.endpoints`), and no range.
