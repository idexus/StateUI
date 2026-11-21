# Interaction

An `Interaction` says what the user's hand moves on a view, and how. It is a
value written with the view - `.interaction(_:)`, on any view
(`ViewContract.interaction`) - and read where the view stands: making one
recognizes nothing, reserves nothing and starts no clock.

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

## On any view

`.interaction(_:)` writes the declaration onto the view's element as a
program ([a program](../core/contracts.md#a-program)); the differ takes of it
the values that stand ([what is refused](#what-is-refused)) and hands them to
the host. The state a value moves is carried as a journey from there on, and
the view is a consumer of its channel while it stands
([a channel's life](../core/journeys.md#a-channels-life)) - unless the view
already wears the state as a property, which is its consumer - so a hand
moves a state nothing draws, and an engine following its journey reads the
hand's place frame by frame.

A state has numbers the hand can name where it is a `Double`, the one number
`value(_:input:)` moves, or a `LayoutParameters`, whose `axes` list them for
`value(_:axis:input:)`. `.containerLength` is the view's
own length along the hand's way, read off where it stands, so the view says
its frame to the host as a layout does. `.frontItem` is a layout's alone.

## On a motion layout

A motion layout reads the interaction as it is described
(`MotionLayout.worked`), together with its axes' mappings, into one record an
axis the run works on (`Hand`): what moves the axis, the hand's range and
snaps, its period, its way and its release from the interaction; the
keyframes, the mapping's own range and the segments from `axis(_:range:…)`.
An axis the interaction moves needs no mapping, and a mapped axis no
interaction.

A value of the layout's own parameters moves the run: its state is told by
the identity of the storage the layout's `parameters:` binding stands on, and
its axis is one of the parameters' `axes`. A value of another state is moved
as on any view, the layout handing it on untouched. The layout writes
the values that stand onto its element as the program the host answers the
hand by (`ViewContract.interaction`), and keeps of each only what its
own arithmetic reads: which way a hand moves it, for the front view's unit,
and its release, for a view the hand throws.

## A view's own press and drag

Beside the values it moves, an interaction says what the hand does to the
view itself, which moves no state:

```text
  .press(values:_:)        the view drawn as an effect answers while a press
                           stands on it
  .elasticPress(...)       a press pulling the view toward itself and growing it
  .drag(_:begins:)         the hand taking the view, along its axes
```

A press is watched, never taken: a tap, a scroll and a drag go on as they
would, and no tap comes of it. Its effect is the application's code, asked
on a frame the press moved with a `PressInput` - everything in it measured
in the view as its layout places it, never as the press draws it, so an
effect moving the view moves nothing it is handed. It answers a
`PresentationOffset`, of which only the numbers `values` names are kept, a
number that is none left out; the press lifted or taken away, the offset is
none. The effect writes no state and calls nothing.

`elasticPress` is that press with the library's effect and a spring of its
own. The view is drawn a little larger wherever the press stands (`scale`);
moved by where the press stands about its middle; and stretched the way it
is moved - wider by how far across the press stands, taller by how far down,
each to `maximumScale` at its edge. The pull is a band stretched - quickly
at first, less and less toward the edge, all of its way there
(`Interaction.stretched`):

```text
  share of the way to the edge    0     0.25   0.5    0.75   1
  share of the pull               0     0.51   0.78   0.92   1      (1 - e^(-2.5 s)) / (1 - e^(-2.5))
```

A pull growing evenly reads as a view sliding under the finger; one that
resists as it goes reads as a view held. One scale by the distance would
grow the view the same whichever way it was pulled; a scale a way stretches
it toward the finger.

The spring is the press's, not a body's: an elastic press that waited for
its view to be a body of some layout would jump on every view that is none
- most of them. So the host brings the view after what the press answers on
the press's own spring (220 ms, damped 0.8), from the frame the press goes
down to the one it rests on, and back the same way. A press with an effect
of the application's has no spring: it is drawn at once, and a body
following its layout is what lags behind it.

A drag says the axes the hand takes the view along and when it does:

```text
  .immediately    as soon as the press moves
  .longPress      once the press has stood still a long press's time
  .directional    once its first move goes the drag's one axis more than
                  across it; a first move across is left to what stands behind
```

The view stays under the hand, over what stands beside it, and goes back
where its layout puts it let go. One press and one drag stand on a view:
two of either said at once are refused together, as two values moving one
number are, and a directional drag given both axes takes the view no way -
it could never tell its way from the other.

The trap is the effect's identity. A closure is made anew at every
description of the view, and a program compared by it would be told to the
host every time; the differ keeps one `HostPressEffect` a view while it
stands and hands it the newest closure, so a view described again alike is
told nothing and still answers by what it was last described with.

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

A declaration that does not stand moves nothing and is said (`complain`,
`Interaction.standing`), never mended into something near it:

- a value that is no number of its state's `axes`;
- the view in front for a unit (`.frontItem`) on a view that runs no layout
  drawing one;
- two values moving one number - both, as neither is the one the author
  meant;
- a range with no end; a magnification's range reaching nought, or told to
  come round;
- coming round with no range of some length to come round over;
- a swipe given no snaps - it goes a snap a hand, and has none to go to;
- the ends of a range to rest at (`.endpoints`), and no range.

## A view thrown away

A drag may let its view go as a dismissal:
`.drag(_:begins:).dismissal(directions:threshold:motion:)` says which ways a
throw dismisses the view, how far it must go one of them - or be thrown, by
`motion`'s law - and the pace of its way out. It is a configuration of the
drag and of nothing else: said of a value, a press or several at once it is
refused, as is one naming no direction or a threshold that is not above
nought, and the drag stands without it. The host is handed the rule as data
beside the drag's axes (`HostDismissal`), so a view described again is the
same program.

`onDismissed` hears `ViewContract.dismissed` - the way the view left and the
hand's speed, a `Dismissal` - once the view is out of sight.
Its handler removes what the view shows; a view no handler removes comes
back, once every handler it started has ended - an awaiting one keeps the
view out of sight while it runs. A motion layout hears the same of its
views with `onItemDismissed`, by the item. How the view leaves, is caught
and comes back is the host layer's
([a view thrown away](../host/interaction.md#a-view-thrown-away)).

