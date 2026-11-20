# The hand over a value

What the user's hand does to a number of a state is the host layer's, once
for every host: the hold, the move under the hand, the rest it is bound
for, the throw. A view says what the hand moves
([views/interaction.md](../views/interaction.md)); the core hands that to
the host as plain values (`HostInteractionProgram`); the host's toolkit
tells the hand; and the sessions (`InteractionSessions`) write the state's
channel. The core runs none of it.

```text
  toolkit ── a press dragged, a trackpad, a wheel, two fingers
     │
  HandReading / PinchReading / HandRecognition      one stream a gesture,
     │                                              said at a frame's start
  InteractionSessions ── one hand a number
     │   InteractionAxis        one number's ends, snaps, turn, release
     │   InteractionArithmetic  the numbers every value goes by
     ▼
  StateChannels.hold / release ── the lane under the hand, then sent on
     │
     ├── every control wearing the state draws the same frame
     └── the core hears a report, origin `.user`:
           a value that moved   the journey's sample, the layout's arithmetic
           a destination moved  the state is written: its readers are asked
```

## The hold

A number a hand holds lives in its state's channel
([motion.md](motion.md#a-lane-a-hand-holds)): its lane stands where the
hand holds it, with no speed, and is bound for where it would rest let go
there. So the value under the hand is the journey's sample - what a layout's
arithmetic, an engine following the journey and every control wearing the
state read alike - and the state's own value is the rest: with snaps, the
snap nearest, written only as the hand passes halfway between two; with
none, the value itself inside its range, written as the hand moves, as a
slider's is.

The hand takes a number where the last frame showed it - not where its run
would stand by now - so what the user pressed stays under the hand; a run
under way stops there for that lane, and the lanes beside it travel on. One
hand holds a number: across every view and window, a second hand on a number
another holds moves nothing of it (`InteractionSessions.take`), and takes it
once the first lets go. A view that leaves the tree lets go of what its hand
held.

What the hand says is said at a frame's start (`HandPace`), so the lane
moves once a frame however often the toolkit tells the hand, and the frame
that hears a move draws it. What a toolkit tells as no number - a move that
is not finite, a scale of nought - moves nothing.

## One number

`InteractionAxis` is one value of the program with the arithmetic of where
it may stand: its ends - an infinity for none - its snaps, its turn where it
comes round, which way it grows, and its release. Snaps are a list, lowest
first - one turn's where the number comes round, repeated a turn on and
back about where it stands - or every multiple of a step, worked out about
where it stands and never listed, so a number with no range has snaps with
no end. Of two snaps as near, the one the hand was going toward is taken,
the lower for a hand standing still.

A magnification is worked on by its logarithm (`toHand`, `fromHand`): the
fingers' spread adds to it, its ends give past them, a snap is nearest and a
throw carries by the logarithm, so spreading and pinching act alike.

## The arithmetic

`InteractionArithmetic` holds the numbers every value goes by, with no
runtime behind them:

```text
  overreach  0.75   the most a value gives past an end, in its units
  throwing   50     how fast a hand lets go to throw, points a second
  shortest   80     the shortest a throw slows in, milliseconds
  settled    0.5    how near its rest a value is there already, points
  notch      100    how far a wheel's notch moves a value with no snaps
```

A magnification's unit of logarithm counts as a hundred points, and a
rotation's unit as its degrees, by which either is judged thrown or settled.

## Past an end

Past an end of a number that does not come round, the number gives less and
less, back as forth (`given`, `pulled`): half as far as the hand at first,
never three quarters of a unit past the end, so no hand carries everything
away. The two are each other's inverse, so a hand coming back the way it
went brings the number back onto the end where it left it. A number that
comes round has no end; a number with no range gives nothing.

## The unit

How far the hand travels for one unit of a number is the input's
`InteractionUnit`:

```text
  .points(n)        n points
  .containerLength  the element's own length along the hand's way
  .frontItem        as far as the element's layout draws its front view
                    for a unit there (`HostLayoutProgram.frontItemUnit`)
```

The length is read at each move, never kept, so a window grown under the
hand keeps a page a screen. The front view is asked of the element's layout
program, whose arithmetic alone knows it
([views/motion-layout.md](../views/motion-layout.md#the-hand)); an element
running none has no such unit, and neither does a room not measured yet -
the hand moves nothing of it then, and throws nothing.

## A swipe

A swiping hand (`.swipe`) moves a number one snap at most, either way from
the snap nearest where it took it (`reach(about:)`), however far it goes: a
trackpad's flick is some 1500 points of the platform's own speeding up, and
a scroll of cards would be through a deck in one. Held past its reach the
number stands on the snap there; let go thrown, it rests on the next of its
three snaps the throw's way; let go still, on the nearest of them.

Its unit is measured once, as the hand takes the number, as the layout
would rest on the snap it took it at, and kept while the hand holds it: a
view that goes out quickly and slows would otherwise quicken the hand as it
slows. A wheel's notch swipes alike - one snap from where the number rests -
and the notches that come while it travels wait for it.

## Two fingers

Two fingers move every number a magnification or a rotation moves, at once,
beside the hand their middle carries ([runtime.md](runtime.md#two-fingers-over-a-layout)):
a magnification by the logarithm of how far they spread, a rotation a unit
every `degreesPerUnit` they turn, clockwise on. Let go, they go on together.
A view held by itself keeps the hand, and the fingers move nothing.

## Letting go

Every number a gesture lets go at once is resolved together
(`InteractionSessions.letGo`), a run a state:

```text
  release        where it rests                       how it goes on
  .projected(m)  where the throw would end, the snap  thrown, or approaching
                 nearest there                        where too slow to throw
  .nearest(m)    the snap nearest where it was left   approaching under m
  .stay          the nearest allowed value            there at once
```

A throw carries the hand's speed on by the release's motion - eased, the
speed for its length over how steeply its curve sets out; a glide or a
spring, as `cubicOut` of its length does - inside the range of a number
that does not come round. A hand slower than `throwing` throws nothing. A
number with no snaps rests where its throw ends.

The numbers let go at once set out together as one run of their state's
channel, each from where the hand left it at its hand's speed, under one
law whatever order they were declared in: a throw's where one is thrown,
else the approach of the longest way, which the others arrive within. A
number that stays, or stands on its rest already, is put there at once, so
it travels nowhere while the others do. The channel says the run as the
user's: the state is written where each number rests before any moves.

A hand taken away - the platform cancelling it - is no letting go: each
number goes onto where its channel says it was bound, with no speed.

## Coming onto where it rests

A number let go comes onto the next snap - the one nearest, or the next a
slow throw reaches, none between - no slower than its state's motion moves
a unit (`InteractionAxis.going`). Let go still, thrown back, or by a hand
whose throw would reach that snap later than the motion at a unit a length,
it approaches under the release's motion - `.nearest`'s own, else the
state's - over as much of the motion's length as the way left is of a unit:
0.4 left of 300 ms is 120 ms on the motion's curve; a spring's response is
cut alike and sets out at the hand's speed toward the snap. A whole motion
for a short way would crawl, and a slow throw would drift onto it.

A throw that gets there sooner sets out at the hand's speed and keeps its
release's motion: a spring settles there as springs do; an eased motion
goes on as a glide no longer than twice its length, so it sets out at the
hand's speed exactly and slows onto the snap - a motion of fixed length
would cover a long throw faster than the hand let go of it; a glide flies
as itself, its `longest` the longest. The two meet where they take the same
time, so a quicker hand never lands later, and a throw never goes back
against the hand.

## A wheel's notch

A wheel turned notch by notch is no hand: a notch moves a number no
distance, but steps it to the next snap the way it turned, from where the
number is going - so notches turned faster than it travels step on from
there - under its state's own motion, keeping the speed it has. A number
that comes round is stepped a turn on past its last snap; one that does not
is held to its ends. A number with no snaps is moved as a hand going a
hundred points would move it, inside its range. A number a hand holds keeps
it.

## A write of the program

A write of the program naming a lane a hand holds meets the hand by the
value's `programWrites`. The channel compares the lanes the write names, not
the state: a write of another number of the same state leaves the hand its
own, and both travel beside each other.

```text
  .interrupt     the gesture ends there: the lane written is the program's,
                 traveling from under the hand; the gesture's other numbers
                 go onto where they were bound; what it says until it ends
                 moves nothing, and the next gesture moves again
  .deferLatest   the hand keeps the lane: the state is going where the
                 program sent it at once, the lane stays under the hand and
                 names no rest over it; let go - or taken away - it travels
                 where the program sent it last, under the state's own
                 motion, and that write's waiter is answered by that run
```

## A program described again

A program is compared as the values it is: described again alike, nothing
is told and nothing under a hand moves. One that changed is told whole, and
the sessions keep what it still moves: a number the program moves no longer,
or by another input, is let go as a hand taken away, once - the others stay
under the hand, whatever else of them changed, a range or snaps read anew
at the next move.
