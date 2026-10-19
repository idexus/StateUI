# Layout engine

`LayoutEngine` is the centre of a layout's motion: a run of views, the
application's arithmetic that places them on the host's frames, the phase the
arithmetic is worked out from, and the hand that moves the phase. A ring, a
fan, a wheel of cards, a timeline and a gallery are one layout with different
arithmetic; `GalleryView` is one with the arithmetic of four shapes written.

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

## A view in its holder

Each item's view stands in a holder the run places, so a frame of the
arithmetic writes the holder and never the author's own view. With no shade
and no tap, the holder is a view of its own, `LayoutItemView`, its one input
the item's view: built again with the same view - its fields the same - it
is carried whole, so a new order of the items describes no holder and builds
no view, the differ matching them by identity alone. A shade is a built node
and a tap a closure the item's value is caught in, which nothing compares, so
a layout given either builds its holders as part of its own description.

## A change at the current phase

What changes a view's pose otherwise than the phase, the room or a followed
state - a view joining or leaving, a new order, a value read in the body - is
a new description of the layout, and it travels, as does a new place the
motion sets out from ([where a motion set out](#where-a-motion-set-out)): each
view goes from where it was shown to where the new arithmetic puts it, under
the layout's motion, while the phase goes on as it goes. A layout that says no
motion of its own (`.inherited`) moves under the application's
(`application.motion`), as a host's channel answers `.inherited`: a change and
a program's write of the phase travel alike, and an application that turned
motion off sees a change land at once. Three layers each own
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

An axis the hand moves is declared whole ([an axis](#an-axis)) and moved
alone: the arithmetic is handed the phase walked by the host with each axis
the hand holds where it holds it, a snap passed is named on that axis, and
another axis travelling under the program goes on beside the hand. A
`Double` phase's one axis is `\.self`.

The type is inferred from the phase lent, `.phase($orbit)`, which stands in
the same expression as the arithmetic; a layout lent none takes its own,
started at `init()`. A phase naming no axes is said.

## An axis

`.axis(_:input:range:keyframes:snaps:wraps:)` is the one declaration of an
axis the hand moves: what moves it (a `LayoutInput`), how far (`range`),
where its layout is worked out (`keyframes`, [keyframes](#keyframes)), where
it may rest (`snaps`), and whether it comes round (`wraps`) - the keyframes
and the snaps both a `LayoutPlaces`, places on the axis. One concept, one
place: an input, a rest and a wrap are never declared apart, so no axis has
an input with no range or a rest with no input.

- THE RANGE is the hand's, not the program's: the hand moves the axis freely
  inside it and less and less past an end ([the hand](#the-hand)); the
  program writes the axis anywhere. Wrapping, its length is the period and
  its upper end the lower one a turn on.
- THE SNAPS are places beside the range's ends, which always are: listed
  (`[1, 2]`, `.at(_:)`), a step from the lower end (`.every(_:)`), or none
  inside (`.limits`) - worked out once into the run's `stops`, lowest first,
  the upper end left out where the axis wraps. NO SNAPS is an axis of its
  own kind: it rests wherever the hand or its throw leaves it, inside its
  range, and is named nothing while the hand holds it - the phase is where
  the run rests or is going, and a held axis with no snaps is going nowhere
  yet; one render a rest, none a frame.
- ONE INPUT AN AXIS, by the type: an axis declared again takes the new
  declaration. ONE INPUT MAY MOVE SEVERAL AXES: each is a hand of its own in
  the run - its hold, its throw and a swipe's grip kept by the axis's place
  in `axes` - so a hand moving two axes moves each by its own unit, and let
  go, each rests its own way. Two axes the hand moves one across and one down
  are a pan ([a pan](#a-pan)).
- THE ELEMENT SAYS what the axes need: `handAxis` where the hand moves them
  one way, `pans` where both, `magnifies` and `rotates` where two fingers do.
- WHAT CANNOT MOVE IS SAID (`complain`) and moves nothing: an axis the
  phase's `axes` does not list, a range with no end, a magnification's range
  reaching nought. A magnification told to come round stops at its ends; a
  swipe given no snaps swipes from end to end, its ends its snaps.

## Keyframes

An axis given `keyframes` has its arithmetic asked only there - at them, the
range's ends and every snap - and the poses between are blended view by
view, by identity. So quite different layouts - a ring at 0, a grid at 1, a
stack at 2 - are one `placements` answering a pose at each keyframe, and the
hand moves through them:

```text
  phase     0 ─────────── 0.4 ─────────── 1 ─────────── 2
  asked     ring                          grid          stack
  shown     ring          ring→grid, 40%  grid          …
```

- ONE ARITHMETIC. There is no second closure: the keyframes only say where
  the engine asks the one it has. With none, it is asked every frame, as
  always.
- A REST IS NEVER A BLEND. The ends and the snaps are always keyframes, so
  wherever the run can come to rest it shows the arithmetic's own answer;
  where a keyframe stands is not where the run rests unless it is a snap -
  a layout passes through a keyframe at 0.5 and rests at 0 and 1.
- ASKED ONCE. A keyframe's pose is worked out the first frame the curve
  needs it (`LayoutPoses`, kept on the description's `Source`) and kept
  while what it was worked out with stands: the description - a render is a
  new `Source` - the room, a write to a state named in `following(_:)` (its
  `stamp`), where the motion set out where the arithmetic is handed it
  (`readsFrom`), and the axes without keyframes. A new pose lands as the
  arithmetic's own answer would.
- A LATTICE. Several axes with keyframes blend one after another, each over
  the poses the next ones give: a tensor product, so the poses are always
  at whole keyframes and no triangulation is needed. A frame reads 2^k poses
  for straight lines and 4^k for a cubic, k the axes with keyframes; an axis
  without keyframes is asked where it stands.
- ROUND AND PAST THE ENDS. On an axis that comes round, the phase is taken
  into one turn; the keyframe at the turn's end is the arithmetic's own
  there, and a curve's neighbours across the seam are the next or the last
  turn's. Past an end, where the hand pulls the run, the end's two keyframes
  give a straight line that goes on, so the views still follow the hand. An
  axis of no length has one keyframe and no line: it is asked where it
  stands, as one with none is.
- WHAT A BLEND CANNOT KNOW. Between two keyframes a view goes the curve's
  way, not the arithmetic's: an arc becomes a chord (more keyframes, or a
  cubic), and arithmetic that jumps between neighbouring keyframes - a card
  taken modulo round a strip, a `zIndex` flipping behind a ring - is drawn
  sweeping across. A size blended lays the view's content out every frame;
  a scale keeps it. On one axis the layouts are a sequence: from 0 to 2 the
  run passes 1. A switch between two layouts with nothing between them is a
  state the arithmetic reads, travelling as [a change at the current
  phase](#a-change-at-the-current-phase).

### The curves

`LayoutInterpolation` is a scalar curve through knots: how many keyframes
either side of the two around a place it reads (`reach`), and the number at
the place. Every curve passes through each keyframe. The library's
`LayoutCurve`:

- `.linear` - straight, `reach` 0;
- `.catmullRom` and `.catmullRom(tension:)` - a cubic whose slope at a
  keyframe is the line through its neighbours, held by `1 - tension`: 0 the
  plain curve, 1 a stop at each keyframe; it may swing past one;
- `.monotone` - a cubic whose slope at a keyframe is limited so it never
  passes its neighbours (Steffen's: local, `reach` 1), so an opacity or a
  size never swings beyond its poses.

At an end of the range the slope is the straight line to the one neighbour.
A curve reading every keyframe - a natural spline - is not offered: its
poses could not be worked out lazily.

### Blending a pose

`LayoutBlend` blends one view's poses channel by channel along the curve:
the bounds (sizes at nought at least); the transform as `LayoutShift`'s
parts - move, turn, slant and scale - the turn unwrapped from keyframe to
keyframe the short way, and one transform at every keyframe left as it is;
opacity and shade inside 0...1, as a cubic overshoots, an unshaded layout
left unshaded. `zIndex` is blended as a number and the drawing order ranked
from it, equal numbers sharing a rank: two views swap as their numbers
cross rather than at half way.

## The hand

The hand is read directly, on the element itself: a finger or a pointer
dragged, a trackpad's two fingers and a wheel are one hand, each host telling
it as its toolkit does and the host layer making it one stream of the
element's `handMoved` (host/runtime.md, the hand over a layout). No scroller
lies over the views, so nothing bounds how far the hand goes: a run that
comes round (`wraps: true`) turns for ever, and the views under the hand
still answer a tap.

- The hand takes the run where it is shown: a journey or a throw under way
  stops there. While it moves, the hand's axis moves with it, its move over
  the unit - the hand moving left moves the run on. Past an end of a run
  that does not come round the run gives less and less, back as forth: half
  as far as the hand at first, never three quarters of a unit past the end,
  so no hand carries every view away. What the arithmetic is handed is
  where the hand holds the run (`held`), and that is the phase's journey
  value for anything else following it (core/journeys.md, where a run shows
  it); the phase itself is named only as the hand passes halfway between
  two snaps, a reading of the hand (`journey.snap(_:to:)`) rather than a
  journey: one render a snap, none a frame. An axis with no snaps is named
  where it comes to rest.
- Let go still, the run travels to the nearest snap as a journey of the
  phase, under the layout's motion - or, with none, stays where the hand
  left it, back onto the end from past one.
- Let go with speed, it is thrown ([a throw](#a-throw)).

The unit is how far the hand travels for one unit of its axis - the input's
`travel`: so many points (`pointsPerUnit`), the room's length along the
axis (`.pages`), or, unless the input says, how far the view drawn in front
goes for one unit where the run stands - of the views the phase moves, the
highest, then the one nearest the middle - measured by the arithmetic a
hundredth of a unit either side. The hand then carries that view with it,
whatever size the room makes the layout: a ring that grows with its window
turns as far under the finger as on a phone. A view standing still over the
run - a dot, a caption - is no front; with nothing moving, a room's length
is a unit. A run whose front view hardly moves - a pile - gives the unit
itself.

The hand moves the axes declared for it alone; where they all go one way,
the host leaves to whatever holds the layout a hand whose first move is more
across that way than along it, a page's scroller.

## Two fingers

Two fingers spreading and turning are inputs of their own:
`.magnification` and `.rotation(degreesPerUnit:)`. The two fingers move
every axis either input moves at once, beside the hand they carry by their
middle ([a pan](#a-pan)), from one stream of the element's `pinchMoved`
(host/runtime.md, two fingers over a layout), each axis's place its own
(`held`, `flung` by the axis): the arithmetic is handed every axis where its
hand holds it.

A magnification is multiplied by how far the fingers spread: the hand works
on the axis's logarithm, so a magnification is a scroll of its logarithm -
the ends give less and less past them, a snap is nearest by the
logarithm, a throw carries the logarithm on - and pinching in acts as
spreading does. Its range stands above nought. A rotation moves a unit
every `degreesPerUnit` the fingers turn, clockwise on. Let go, the axes go
on together, each to where it would end under its input's `throwing` - the
snap nearest that - or onto the nearest as a hand let go still does; a unit of
a magnification's logarithm counts as a hundred device units and a
rotation's as its degrees, by which either is judged thrown or settled. A
view held by itself keeps the hand, and the fingers move nothing.

## A pan

A pan is two axes the hand moves, one across (`.scroll(.horizontal)`) and
one down (`.scroll(.vertical)`): each moves with its part of the hand's move,
the unit each's own - so many points, else the view in front's along that
axis. No input of its own: the ways the axes' inputs go make it. The element
says `pans` and no `handAxis`, so a host hears the hand every way and the
host layer claims every first move (host/runtime.md, the hand over a
layout); a wheel's notches step each axis their way. Let go, every axis the
hand moves is thrown with its part of the speed and comes to rest its own
way, the run travelling to all of their rests as one phase.

## A swipe

`.swipe(_:)` is the hand of a deck or of pages: one hand moves the run one
snap at most, either way from the snap nearest where it took it,
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
reached. Its axis needs snaps; given none, the range's ends are its snaps.

Its unit is measured once, as the hand takes the run, as if the run stood on
the target it took it at, and kept while the hand holds it: a view that goes
out quickly and slows - a card swung aside and tucked under the next - would
otherwise quicken the hand as it slows, and the moment the hand caught it on
its way would decide how fast it moves. A scroll measures where the run
stands at each move, a ring of views keeping to the finger all round.

`.pages(_:)` is a swipe whose unit is the room's length along its axis: a
board of icons is a screen, the boards side by side a room apart, and a hand
across the room turns one. The room is read at each move, never kept, so a
window grown or a phone turned under the hand keeps a board a screen; no
front view is measured, since every icon of a board moves alike and the
nearest to the middle may stand still between boards.

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
where the hand let go - comes onto it as a run let go still does: a throw
never goes back against the hand. The engine runs again each frame while the
throw goes on (`flung`), and the hand's axis is let go on the target. A
destination the program writes meanwhile ends the throw.

## Coming onto a target

A run let go comes onto the next target - the one it stands nearest, or the
next a slow throw reaches, none between - no slower than the layout's motion
moves a unit. Let go still, thrown back, or by a hand whose throw would reach
that target later than the motion at a unit a length, the run approaches it
under the layout's motion over as much of the motion's length as the way left
is of a unit: 0.4 left of 300 ms is 120 ms on the motion's curve; a spring's
response is cut alike and sets out at the hand's speed. A throw that gets
there sooner sets out at the hand's speed, as above. The two meet where they
take the same time, so a quicker hand never lands later.

A whole motion for a short way would crawl - the last tenth of a card over
300 ms - and a slow throw would drift onto it over twice the throw's length.
A throw past several targets keeps its own motion: a long glide is what its
input asked for, and only the landing on the next target is the motion's.

AN AXIS WITH NO SNAPS has no target to come onto: where it rests is where
its throw ends, so let go moving it is always thrown, setting out at the
hand's speed and slowing onto that end. An approach there would be a short
way under a motion cut to it - a spring's response a tenth of its own -
leaping ahead of the hand in the first frame and back at the end, the more
so the faster the hand. A hand slower than a throw is let go still: nothing
carries it on, and it rests where it was let go.

The approach is carried in the core as a throw is (`flung`), the phase named
the target at once; under less motion it lands at once, as a journey does. A
hand taking the run on its way - a throw or an approach - takes it where it is
shown, never where it is going.

## One view in the hand

`.itemDrag(begins:)` lets the hand take one view by itself rather than move
the run: by a first move across the layout's axis (`.across` - a card pulled
up out of a deck that scrolls sideways), or by a press standing still a long
press's time (`.held` - an icon lifted off a board). Which hand it is - the
run's, a view's or the page's - is the host layer's rule, one for every host
([the hand over a layout](../host/runtime.md#the-hand-over-a-layout)); a host
passes the press's point and decides nothing more. The element hears that
hand as an event of its own, `itemMoved`: its phase, where it is in the
layout, its speed at the lift, and how long it has stood still - told again
each long press's time it stands, so an application can turn a board while
an icon is held at its edge.

The core finds the view under the press from what the run last showed: the
one drawn on top - the highest `zIndex`, then the later - whose place, turned
as it is drawn about its middle, covers the point; a view drawn clear is
passed over. The held view is the third layer's: its middle where the middle
it was taken by has moved with the hand, over every other view. Everything
else of it is its place's, as shown, and the view's own: the application is
told as the hand takes it and as it lets it go (`ItemDrag.phase`), and lifts
it there by the view's own properties - `.scale` under the view's `.motion`,
a spring of its own - which the run never writes over; a hand that cannot
see its view lifted does not know it has it. Its place may change meanwhile
- the application moves its item in the order as the hand crosses a slot,
and the others travel to their new places as any change at the current
phase does - but the held view stays under the hand, so it never leaves the
finger.

Let go, the difference between where it is shown and its place becomes a
change under the layout's motion, setting out at the hand's speed: the view
settles into its slot as a changed order would. With `.onItemDismissed`, a
view the hand took far enough one of its ways - or threw far enough, as a
throw of the input would carry it - flies on at the hand's speed, no slower
than the room's length a motion's length, and its item is told once it has
left the room; the application removes the item then. The handler runs after
the frame, as a job of the UI thread, never inside the cycle.

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
run keeps it. An axis with no snaps has no next place: a notch moves it as a
hand going a hundred points does, inside its range. The host tells the
notches (`handStepped`); the host layer adds a fine wheel's parts of a notch
up to whole ones.

## Coming to rest

When the hand lets go the run goes on to where it comes to rest, from where
the hand left it - a journey of the phase, or a throw. Each axis rests on
its own: on the snap nearest where its throw would end, or, with no snaps,
there itself inside its range - and only its own hand moves it there, a
settle of another leaving it where the program put it. The axes the hand or
the fingers let go at once are each NAMED where they rest before any goes
on, and the phase is sent on no journey: a journey of the whole phase would
have the host walk an axis the hand held - which nothing named while it held
it, an axis with no snaps - from where the host last had it, the value
snapped meanwhile left to the host's walk, so the axis let go would leap
back to where the hand took it and come again (a pan let go across, its
down axis, on every host).

Under the hand only the hand's axes are named - each on the nearest of its
snaps - so an axis the hand does not move never jumps as the hand passes.
Where an axis comes round, its snaps repeat every turn and the nearest is
taken a turn on or back: the axis has no end, so a write of one more always
moves the run on.
