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
written, and once in the turn of every render that describes the layout,
before the views it puts in are drawn (host/runtime.md, one turn). It is
handed the room at the layout's own origin and the phase as it stands this
frame, and answers one placement a view. An answer of another length is
said once and made to fit, a missing view standing at the top left.

A run lands as written (placement.md, a run lands as written): what travels
is the phase it is worked out from. A host walking places from one to the next
draws a straight line - a chord across a ring, nothing at all for a whole
turn - where the arithmetic run on a phase keeps every view on its path.

A room not yet measured places nothing: each child stands in the whole room
until the platform reports one, never placed by arithmetic over a room of
nothing - and a hand over it moves nothing where the input gives no unit, as
no view is drawn to carry.

A value read in the body is a change of the description, the layout built
again and its arithmetic with it - and the change travels ([a change at the
current phase](#a-change-at-the-current-phase)); a state the arithmetic reads
that moves on the host's frames - a finger's - is named in `following(_:)`
instead, or its writes run nothing.

## A change at the current phase

What changes a view's pose otherwise than the phase, the room or a followed
state - a view joining or leaving, a new order, a value read in the body - is
a new description of the layout, and it travels, as does a new place the
motion sets out from ([where a motion set out](#where-a-motion-set-out)): each
view goes from where it was shown to where the new arithmetic puts it, under
the layout's motion, while the phase goes on as it goes. Three layers each own
one thing: the motion times the phase, the arithmetic turns a phase into
poses, and a shift per identity (`LayoutShift`) turns a pose into what is
shown.

A description is told apart by a number each gets as it is made (an object's
address would not do: one let go is soon another's). On the first frame of
a new one, the engine works its arithmetic out where the last frame stood -
that phase, that room - and compares it identity by identity with the last
frame's poses: a view whose pose is the same goes on as it was, so a render
that changes nothing changes no way, and a phase travelling meanwhile is no
change; a view whose pose differs is shifted from where the last frame
showed it, a view new to the run from nothing - it fades in. A view leaving
goes at once, and the others close up. The shift decays to nought under
the layout's motion (`.standard` where it inherits one), setting out at the
speed a shift it replaces had, so a change changed again does not jump; the
engine runs again each frame while one is on its way. Less motion, or a
motion of none, shows a change at once, and a new room never travels: the
layout follows the window.

A shift is the bounds' place and size, the opacity and the shade apart, and
the transform as the correction that takes the pose's to the one shown,
decomposed into a move, a turn - the short way - a slant and a scale: a
blend of the matrices would squash a turned view, and a correction at
nought is the pose's own transform, slant and all. The order is the pose's
at once; a shade the layout draws none of is not blended.

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

## Where a motion set out

Beside the phase, the arithmetic may be handed where the run's motion set
out (`placements: { room, phase, from in }`): the phase the run stood at
when the hand took it, a throw or a journey of the phase carried it away. A
pose drawn from the phase alone cannot tell which card set out - a phase of
1.3 is the first card going on or the second coming back - and the phase's
side of `from` is the way the run goes.

It is kept, not worked out from the direction of the last frame: a hand
going on and turning back past `from` hands the same `from`, and at `from`
itself every view stands at the whole step it stood at, where a pose for
leaving and one for staying agree - nothing drawn jumps as the way turns. A
hand taking the run on its way keeps it too: the card it catches goes on
with it, either way.

Passing a target on the hand's axis, the motion sets out from the last it
passed, either way, and at rest from where the run stands. Passing is again a
whole step, so the cards go out one by one without a jump: one long hand, a
throw across several targets, two quick swipes a wheel reads as one hand.
Should an arithmetic draw a whole step otherwise for another `from`, the
change travels as a change of the description does ([a change at the
current phase](#a-change-at-the-current-phase)), each view from where it was
shown. The run measuring the hand's unit is handed the `from` of the moment.

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
  the unit - the hand moving left moves the run on - and the way past an
  end of a run that does not come round counts half, back as forth. What the arithmetic is
  handed is where the hand holds the run (`held`); the phase itself is named
  only as the hand passes halfway between two targets, a reading of the hand
  (`journey.snap(_:to:)`) rather than a journey: one render a target, none a
  frame.
- Let go still, the run travels to the nearest target as a journey of the
  phase, under the layout's motion.
- Let go with speed, it is thrown ([a throw](#a-throw)).

The unit is how far the hand travels for one unit of its axis. Unless the
input gives one (`pointsPerUnit`), it is how far the view drawn in front
goes for one unit where the run stands - of the views the phase moves, the
highest, then the one nearest the middle - measured by the arithmetic a
hundredth of a unit either side. The hand then carries that view with it,
whatever size the room makes the layout: a ring that grows with its window
turns as far under the finger as on a phone. A view standing still over the
run - a dot, a caption - is no front; with nothing moving, a room's length
is a unit. A run whose front view hardly moves - a pile - gives the unit
itself.

The hand moves one axis of the phase alone; the host leaves to whatever holds
the layout a hand whose first move is more across the layout's axis than
along it, a page's scroller.

## A swipe

`.swipe(_:)` is the hand of a deck or of pages: one hand moves the run one
snap target at most, either way from the target nearest where it took it,
however far it goes. A trackpad's quick flick is some 1500 points of the
platform's own speeding up before the fingers lift, and a throw on top - a
scroll of cards a few hundred points apart is through the deck in one flick;
a swipe is one card, as a finger's flick on a phone is. Held past its reach,
the run stands on the target there; let go thrown, it goes on to the next of
its three targets the throw's way - the one beyond, or back to where it took
it from beyond that - and let go still, to the nearest of them. A wheel's
notches swipe alike: a notch moves the run one target from where it rests,
and the notches that come while it goes wait for it - the rest of a burst, a
spring passing its target, which would otherwise count as the next card
reached.

Its unit is measured once, as the hand takes the run, as if the run stood on
the target it took it at, and kept while the hand holds it: a view that goes
out quickly and slows - a card swung aside and tucked under the next - would
otherwise quicken the hand as it slows, and the moment the hand caught it on
its way would decide how fast it moves. A scroll measures where the run
stands at each move, a ring of views keeping to the finger all round.

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

## A wheel's notch

A wheel turned notch by notch is no hand: a notch moves the run no distance,
but steps it to the next target the way it turned, from the target the run
is going to - a journey's or a throw's - so notches turned faster than the
run travels step on from there rather than from where it is shown. The run
travels under the layout's motion; a run that comes round is stepped a turn
on or back past its last target, one that does not is held to its ends. A
notch is a step whatever a target's size - a run of large cards turns one a
notch, as of small ones - which a distance cannot be: a mouse's notch is a
few points, so one turned slowly would never carry the run past half a card,
and the run would come back to where it stood after each. A hand holding the
run keeps it. The host tells the notches (`handStepped`); the host layer adds
a fine wheel's parts of a notch up to whole ones.

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
