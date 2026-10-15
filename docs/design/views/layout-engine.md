# Layout engine

`LayoutEngine` is the centre of a layout's motion: a run of views, the
application's arithmetic that places them on the host's frames, the phase the
arithmetic is worked out from, and the hand that moves the phase. A ring, a
fan, a wheel of cards, a timeline and a gallery are one layout with different
arithmetic; `GalleryView` is one with the arithmetic of three shapes written.

```text
  LayoutEngine - the element, a host's ZStack, wearing the phase   ◀── the host walks it
   │             and hearing the hand over it (handMoved, handAxis) ◀── a finger, a pointer,
   ├── holder ── the author's view [ + the shade, second ]   ◀─┐      a trackpad, a wheel
   └── …                                                       ├─ one run of placements,
         engine(following: room, phase, held, flung, followed…) ┘  written by the engine
```

## The element

The layout is an element of its own, `LayoutEngineContract`, which every host
stands on its ZStack: children one over another, each where a run of
placements on the element's own `area` puts it, or in the whole room until a
run comes. It is the element an author's modifiers reach - a background, a
border, a clip - so the node its contract describes is the one the author
writes on, and its row in the matrix is proven by its own family. It wears
the phase both ways (`LayoutEngineContract.phase`), so the host layer's
channel walks it under the layout's motion and says every frame where it
stands; no host draws it, and every host records it realized alike.

It has no size of its own: it takes the room its layout gives it, whatever
its views need (host/layout.md, a layout engine). The views stand where
arithmetic of that room puts them, so a size taken from them would feed the
room the arithmetic is worked out from.

Each view sits in a holder the run places, which keeps two writers apart:
every placement is written onto the holder, so an author's own opacity or
turn on the view beneath stays the author's and is never overwritten by a
frame of arithmetic. A shade is the holder's second child; both children are
the library's, so their order is its guarantee.

The run places every child: the views, in the items' order. A host lays out
by arithmetic only the children a run leaves unplaced, so one run for all of
them keeps every host's ZStack to the one rule it already has.

## The run

The arithmetic runs on the host's frames, never in a render: whenever the
room, the phase - written by the program or walked by the host - where the
hand holds the run, a throw going on, or a state named in `following(_:)` is
written, and once after every render that describes the layout. It is handed the room at the layout's own origin and the
phase as it stands this frame, and answers one placement a view. An answer of
another length is said once and made to fit, a missing view standing at the
top left.

A run lands as written (placement.md, a run lands as written): what travels
is the phase it is worked out from. A host walking places from one to the next
draws a straight line - a chord across a ring, nothing at all for a whole
turn - where the arithmetic run on a phase keeps every view on its path.

A room not yet measured places nothing: each child stands in the whole room
until the platform reports one, never placed by arithmetic over a room of
nothing. The hand acts all the same, so a move reported before the room is
still named.

A value read in the body is a change of the description, the layout built
again and its arithmetic with it; a state the arithmetic reads that moves on
the host's frames - a finger's - is named in `following(_:)` instead, or its
writes run nothing.

## The phase

The phase is where the run rests or is going, two-way: the program writes it,
the hand names it. It is the one thing that travels: a write is its
destination, which the host walks under the layout's motion and reports frame
by frame, so `$phase.journey.move(to:)` is awaited until the run arrives and
the arithmetic is handed each frame where the phase stands - never the
destination at once, which would make a ring jump. Under the hand, the hand's
axis is where the hand holds it.

The phase lent is a state, `$turn`: a binding worked out from others has no
image to wear, so its phase would jump where it is sent, and the layout says
so once. The engine follows the phase itself, so a new one wakes the arithmetic and
builds nothing; a change of room moves no phase.

## A phase of many axes

A phase is a `LayoutPhase`: a struct of numbers, its axes listed as key
paths, and `Double` the phase of one axis. An axis is a degree of freedom the
hand or the program moves on its own - how far a ring is turned, how near it
stands; how many dimensions the layout has is the arithmetic's, which may
read one axis for several things. The element wears the whole phase, one
lane an axis in the order `axes` names them: a part of a state is never
carried, so one state is one channel however many axes it has.

A hand drives one axis (`.input(_:drives:)`) and moves it alone: the
arithmetic is handed the phase walked by the host with the hand's axis where
the hand holds it, a target passed is named on that axis, and another axis
travelling under the program goes on beside the hand. `.input(_:)` is a `Double`
phase's, whose one axis is `\.self`.

The type is inferred from the phase lent, `.phase($orbit)`, which stands in
the same expression as the arithmetic; a layout lent none takes its own,
started at `init()`. A phase naming no axes is said.

## The hand

The hand is read directly, on the element itself: a finger or a pointer
dragged, a trackpad's two fingers and a wheel are one hand, each host telling
it as its toolkit does and the host layer making it one stream of the
element's `handMoved` (host/runtime.md, the hand over a layout). No scroller
lies over the views, so nothing bounds how far the hand goes: a run that
comes round (`wraps(every:)`) turns for ever, and the views under the hand
still answer a tap.

- The hand takes the run where it is shown: a journey or a throw under way
  stops there. While it moves, the hand's axis moves with it, its move over
  `pointsPerUnit` - the hand moving left moves the run on - and past an end
  of a run that does not come round, half as far. What the arithmetic is
  handed is where the hand holds the run (`held`); the phase itself is named
  only as the hand passes halfway between two targets, a reading of the hand
  (`journey.snap(_:to:)`) rather than a journey: one render a target, none a
  frame.
- Let go still, the run travels to the nearest target as a journey of the
  phase, under the layout's motion.
- Let go with speed, it is thrown ([a throw](#a-throw)).

The hand moves one axis of the phase alone; the host leaves to whatever holds
the layout a hand whose first move is more across the layout's axis than
along it, a page's scroller.

## A throw

A throw goes on to the target nearest where it would end: the speed the hand
let go at, carried by the input's `throwing` - a motion like any other - says
how much farther it would go (eased, the speed for its length over how
steeply its curve sets out; a spring, for a third of its response; 400 ms of
`cubicOut` unless said, about an eighth of a second's worth of the speed), and
the nearest target to that end - a turn on or back where
the run comes round, never past the last of one that does not - is where it
goes. The phase is named that target at once: the state is where the run is
going.

The way there is carried in the core, on the hand's axis, rather than walked
by the host under the layout's motion: a motion of fixed length would cover a
long throw faster than the hand let go of it, and the run would speed up
after the lift. Eased, the axis follows the curve over a length chosen so it
sets out at the hand's speed exactly - `D` times the curve's first slope over
the speed, the motion's own length where the target is where the throw would
end, shorter where it is nearer - and stops on the target; a spring settles
there from the hand's speed, as springs do (`HostMotionLaw`). A throw too slow to
carry the run past the target it stands nearest - that target at or behind
where the hand let go - slides there under the layout's motion, as a run let
go still does: a throw never goes back against the hand. The engine runs again each
frame while the throw goes on (`flung`), and the hand's axis is let go on the
target. A destination the program writes meanwhile ends the throw.

## Coming to rest

When the hand lets go the run goes on to where it comes to rest, from where
the hand left it - a journey of the phase, or a throw. Two ways say where
that is, and both may stand on one layout:

- `.snap(\.axis, to:)` gives an axis targets of its own. It is independent:
  it rests on the nearest of them, and only its own hand moves it there - a
  settle of another hand leaves it where the program put it.
- `.snapTargets([...])` lists whole phases, the combinations allowed. The
  nearest is the one at the least distance over the axes without targets of
  their own, every one of those axes travelling to it; of two as near, the
  first listed. A `Double` phase's targets are of this kind.

Under the hand only the hand's axis is named - the nearest place on it any
target names - so an axis the hand does not drive never jumps as the hand
passes; the whole combination is reached at rest. Where the hand's axis comes
round, its targets repeat every period and the nearest is taken a turn on or
back: the axis has no end, so a write of one more always moves the run on.
