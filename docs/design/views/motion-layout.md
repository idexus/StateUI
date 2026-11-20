# Motion layout

`MotionLayout` is the center of a layout's motion: a run of views, the
application's arithmetic that places them on the host's frames, the parameters the
arithmetic is worked out from, and the hand that moves the parameters. A ring, a
fan, a wheel of cards, a timeline and a gallery are one layout with different
arithmetic; `GalleryView` is one with the arithmetic of four shapes written.
Its run and its bodies are a movement worked out on the core's side, beside
the three owners every other moving value has
([architecture](../architecture.md#a-moving-value-has-three-owners)).

```text
  MotionLayout - the element, a host's ZStack, wearing the parameters   ◀── the host walks it,
   │             and saying what the hand moves of them (interaction)        and holds it under the hand
   ├── holder ── the author's view [ + the shade, second ]   ◀─┐
   └── …                                                       ├─ one run of placements,
         engine(following: room, parameters, followed…)        ┘  written by the engine
```

## The element

The layout is an element of its own, `MotionLayoutContract`, which every host
stands on its ZStack: children one over another, each where the run its
layout program answers puts it
([a layout's program](../core/layout-program.md)), or in the whole room until
a run comes. It is the element an author's modifiers reach - a background, a
border, a clip - so the node its contract describes is the one the author
writes on, and its row in the matrix is proven by its own family. It wears
the parameters both ways (`MotionLayoutContract.parameters`), so the host layer's
channel walks it under the layout's motion and says every frame where it
stands; no host draws it, and every host records it realized alike.

It takes the room its layout gives it, whatever its views need
(host/layout.md, a motion layout), unless it says a size
([a size of its own](#a-size-of-its-own)). The views stand where arithmetic
of that room puts them, so a size taken from where they stand would feed
the room the arithmetic is worked out from.

Each view sits in a holder the run places, which keeps two writers apart:
every placement is written onto the holder, so an author's own opacity or
turn on the view beneath stays the author's and is never overwritten by a
frame of arithmetic. A shade is the holder's second child; both children are
the library's, so their order is its guarantee.

The run places every child: the views, in the items' order. A host lays out
by arithmetic only the children a run leaves unplaced, so one run for all of
them keeps every host's ZStack to the one rule it already has.

## Right to left

A motion layout places its views as its arithmetic writes them, laid out
either way: its placements are the author's moves and turns, and StateUI
turns no transform or drawing right to left - a dial, a clock, a light table
or a body thrown about would come out the other way round. Which way the
hand moves the run is the author's arithmetic too. A layout in reading order
says so (`mirrorsRightToLeft(true)`, `MotionLayoutContract.mirrorsRightToLeft`):
laid out right to left, the host layer turns its run about the room's middle
and tells it the hand the mirror's way, by the rule every layout follows
(host/layout.md, right to left), so the arithmetic is written left to right
once. `GalleryView` is such a layout, StateUI's composition saying what an
author's own carousel says.

## The run

The arithmetic runs on the host's frames, never in a render: whenever the
host says a new room, the parameters - written by the program or walked by the
host - where the hand holds the run, a throw going on, or a state named in
`following(_:)` is written, and once in the turn of every render that
describes the layout, before the views it puts in are drawn (host/runtime.md,
one turn). It is
handed a context (`LayoutContext`) - the room at the layout's own origin, as
`bounds`, and the views - and the parameters as they stand this
frame, and answers one placement a view. An answer of another length is
said once and made to fit, a missing view standing at the top left.

A run lands as written (placement.md, a run lands as written): what travels
are the parameters it is worked out from. A host walking places from one to the next
draws a straight line - a chord across a ring, nothing at all for a whole
turn - where the arithmetic run on parameters keeps every view on its path.

A room not yet measured places nothing: each child stands in the whole room
until the host says one, never placed by arithmetic over a room of
nothing - and a hand over it moves nothing where the input gives no unit, as
no view is drawn to carry.

A value read in the body is a change of the description, the layout built
again and its arithmetic with it - and the change travels ([a change where the
parameters stand](#a-change-where-the-parameters-stand)); a state the arithmetic reads
that moves on the host's frames - a finger's - is named in `following(_:)`
instead, or its writes run nothing. `following($x)` runs the arithmetic at a
write of where the state is going; `following($x.journey)` at every frame of
the way there, the layout a consumer of the state's channel so
`$x.journey.sample` answers in the arithmetic.

## Measuring a view

The views the arithmetic is handed (`context.subviews`, a `LayoutSubviews`)
are handles in the items' order, found by place or by an item's identity.
A handle holds no view: `sizeThatFits(width:height:)` asks the host how large
the view is in a room offered, and `firstBaseline(width:height:)` where its
first line of words rests. The two sides are a `LayoutProposal` within, the
type a layout's own `measure` is handed its room as.

```text
  sizeThatFits()             the size the view takes by itself
  sizeThatFits(width: 200)   its words wrapped to 200 points, as tall as that makes it
```

A side left out offers nothing along it; a side below nought is nought, and
one that is no number offers nothing and is said. The answer has the view's
stated sizes and bounds in it and leaves its margin out; an answer that is
no size is nought, said once. Measuring writes nothing: the arithmetic
reads sizes and answers placements, and a placement's own bounds are what
the view is drawn at - a size measured is one the arithmetic may hand back
or not.

A layout that measures is worked out again when a view of it may measure
otherwise ([measuring the views](../core/layout-program.md#measuring-the-views)).
The room is no result of the measuring: the arithmetic never reads where
the layout or a view was last drawn, so no answer feeds itself.

Every host measures a view in the width offered, as its own layouts do: a
height offered is part of the room asked, and changes no host's answer.
A test's window with no toolkit measures every view nought.

## A size of its own

`measure(_:)` gives the layout a size: its closure is handed the room
offered and the views (`LayoutMeasurementContext`) and the parameters as
they stand, and answers a `LayoutSize` - a row as wide as its views side by
side, a column as tall as them stacked. Without it the layout takes the
room it is given, and its size is its padding alone. A stated `width` or
`height` bounds the answer as it bounds any view's; a side that is no
number, or below nought, is nought, said once.

The host asks it whenever it measures the layout, in the width its own
layout offers; the Web asks with no width, the browser telling none before
it lays the page out. A working-out that makes the layout say another size
has its host measure it again, and one that says the same size asks
nothing.

The trap is taking the size from where the views stand. That is the room
the arithmetic was worked out in, read back: `measure` reads what the views
measure, never where a run put them.

## An answer made to fit

The placements are the application's arithmetic, and the run takes what it
answers as it can: one placement a view, in the items' order - fewer stand
the rest at the top left, more let the extra go - and every number finite: a
division by nothing or an infinity stands as a placement at the top left
holds that number, its bounds at nought and its opacity at one. Each is said
once (`complain`), and no host is handed a number it cannot place. What a
host tells the run is taken the same way: a hand's move or speed, two
fingers' degrees and a held view's place that is no finite number is
nought, a scale that is none or no larger than nought is one, and a wheel's
notches of no number step nothing - the parameters the arithmetic is handed
stay numbers.

## A view in its holder

Each item's view stands in a holder the run places, so a frame of the
arithmetic writes the holder and never the author's own view. With no shade
and no tap, the holder is a view of its own, `LayoutItemView`, its one input
the item's view: built again with the same view - its fields the same - it
is carried whole, so a new order of the items describes no holder and builds
no view, the differ matching them by identity alone. A shade is a built node
and a tap a closure the item's value is caught in, which nothing compares, so
a layout given either builds its holders as part of its own description.

## A view is its item's identity

A view's identity is its item's own, the value `id:` names, compared as that
value: two items that describe alike are two views, and none is spelled. The
layout numbers each identity as it first appears (`LayoutSlotNumbers`) and
keeps the number while the identity stands in it, never giving one again; the
identities are compared once a render, as the numbers are given, and every
frame keys its views by number - what each was shown at, where it travels,
the one the hand holds. An identity that leaves and comes back takes a new
number, as the view it names is new to the run.

## A change where the parameters stand

What changes a view's pose otherwise than the parameters, the room or a followed
state - a view joining or leaving, a new order, a value read in the body - is
a new description of the layout, and it travels, as does a new place the
motion sets out from ([where a motion set out](#where-a-motion-set-out)): each
view goes from where it was shown to where the new arithmetic puts it, as a
body ([bodies](#bodies)), while the parameters go on as they
go. Three layers each own one thing: the motion times the parameters, the
arithmetic turns parameters into poses, and a body per identity - its shift
(`LayoutShift`) and how fast it goes, kept by the host layer - turns a pose
into what is shown.

A description is told apart by a number each gets as it is made
(an object's address would not do: one let go is soon another's). On the first frame of
a new one, the engine works its arithmetic out where the last frame stood -
those parameters, that room - and compares it identity by identity with the last
frame's poses: a view whose pose is the same goes on as it was, so a render
that changes nothing changes no way, and parameters traveling meanwhile is no
change; a view whose pose differs is answered that pose as the place its way
is measured to. The host layer shifts it from where it last showed it, a
view new to the run from nothing - it fades in. A view leaving
goes at once, and the others close up. The shift is a body's, going on at
the speed the body had, so a change changed again does not jump; the poses
then stand as the new description puts them at the last frame's parameters, so a
body following its place is carried by the parameters' move alone. The
display's frames step a body on its way; the engine runs for none of them.
Less motion, or a view with no body, shows a change at once, and a new room
never travels: the layout follows the window.

A shift is the bounds' place and size, the opacity and the shade apart, and
the transform's five drawn numbers apart - its move, its turn the short way,
its width and its height - each traveling on its own, as a view's own
transform does: a blend of the matrices would squash a turned view, and a
slant no view draws would be carried for nothing (types/transforms.md, the
shear limit). A shift at nought is the pose itself. The order is the pose's
at once; a shade the layout draws none of is not blended.

## Bodies

How a view comes onto its place is its body (`LayoutBody`), which is one of
three:

```text
  .none            no body: the view stands at its place at once
  .onChange(s)     answers a change of the layout on the spring s; the parameters carry it with no lag
  .followsLayout(s) answers a change, and lags behind a place that moves too
```

The layout says one for every view (`.layoutBodies(_:)`, the member every
layout has, `LayoutContract.layoutBodies`; a motion layout that says none
is `.onChange()` - the standard spring, 300 ms critically damped), and a
view says its own (`.layoutBody(_:)`, `ViewContract.layoutBody`), which
wins: a view with a body in a layout of none travels, one with none in a
layout of bodies lands. The layout answers the host each view's own body
alone; which body a view is, the host layer resolves as it does for every
layout ([a child that is a body](../host/motion.md#a-child-that-is-a-body)).
A view's own is read off each item's view
the first time a frame asks, and again once that view is built again - a
state the view reads, a switch turning its body on, builds the view without
the layout or its holder, so the layout forgets that view's body as it
builds it, shade or none.

The layout answers each view's place and its body; the host layer brings
the view there ([the answer](../core/layout-program.md#the-answer),
[bodies](../host/layout.md#bodies)). Each view shown a shift of is a body:
a mass on a spring to its place, its shift's lanes and how fast each goes
(`LayoutBodies`), pulled onto nought on its body's spring. The bodies are
worked out at
a fixed step - 240 a second, each step `HostMotionLaw`'s own closed form for
one lane (`HostMotionLaw.spring`), so a step of any spring is where the
spring then is and none runs away - with an accumulator, so other frames,
another host or another rate bring a body to the same place; a frame works
out at most 32 steps, and bodies further behind let the rest go, slowing
rather than spending a frame catching up (the Web without a JIT). A body as
near and as slow as an animation counts arrived is one no more, and one
still moving the longest a spring animates since it was set or carried lands
on its place, as an animation does - as does one whose step comes out no
number, its speed told back per second included.

A body answering a change alone is at its place but where a change shifted
it: the parameters and the hand carry it exactly. A body following its layout
(`.followsLayout(response:damping:)`) is carried by its place's moves too: the place moving
under it since the last frame, it keeps where it was shown and its spring
pulls it after - a card lagging while the run scrolls and settling back,
flying past where a throw stops at the end and coming back. The view the hand
lets go goes back onto its place as a body setting out at the hand's speed.
The parameters' law is their state's alone: how a change, a join or a hand's let go
comes onto a place is the body's. A view whose body becomes none on its way
stands at its place at the next frame. Under less motion no body stands:
every view at its place.

The trap is a body that is any motion. Following a place that keeps moving
is a spring's answer; an eased length and a glide are laws of a finite way,
and a body given one would have to guess when its way began. A body takes a
spring's two numbers and nothing else.

## At rest

The run is at rest where no hand holds it - the host's word
(`LayoutProgramSlot.handHolds`) - the parameters' channel shows them at their
destination and no body of the world is on its way - whatever moved it: the
program's journey, the hand's throw, a change, a view let go. Each frame the
engine runs, it notes whether the run rests (`LayoutShown.resting`); coming
to rest after it moved, it tells `.onSettled` once, with the parameters it rests
at, after the frame (as a dismissal is told), its runs owned by the layout
and orphaned as it leaves. Laid out at rest, it tells nothing. One event of
rest stands for every way the run moves: there is no rest of the parameters apart
from the bodies' (the journey's own `MotionRun` waits for the parameters alone).

## The parameters

The parameters are where the run rests or is going, two-way: the program writes them,
the hand names the snap it is bound for. It is the one thing that travels: a write is its
destination, which the host walks under the state's own motion
(`@State(motion:)`, else the application's) and reports frame
by frame, so `$parameters.journey.move(to:)` is awaited until the run arrives and
the arithmetic is handed each frame where the parameters stand - never the
destination at once, which would make a ring jump. Under the hand, the hand's
axis stands in the channel where the hand holds it.

The parameters lent are a state, `$turn`, or a conversion of one - a second
state the host carries (core/journeys.md#conversions), its destination walked as
any state's. The layout gives them no motion of its own: a shared channel
travels under its state's motion, whichever control shows it, and a layout
is one such control. A hand let go short of a rest comes onto it under the
same motion. The engine follows the parameters themselves, so a new one wakes the arithmetic and
builds nothing; a change of room moves no parameters.

## Where a motion set out

Beside the parameters, the arithmetic may be handed where the run's motion set
out (`placements: { context, parameters, segmentStart in }`): the parameters the run stood at
when the hand took it, a throw or a journey of the parameters carried it away. A
pose drawn from the parameters alone cannot tell which card set out - parameters at
1.3 are the first card going on or the second coming back - and the parameters'
side of `from` is the way the run goes.

It is kept, not worked out from the direction of the last frame: a hand
going on and turning back past `from` hands the same `from`, and at `from`
itself every view stands at the whole step it stood at, where a pose for
leaving and one for staying agree - nothing drawn jumps as the way turns. A
hand taking the run on its way keeps it too: the card it catches goes on
with it, either way.

Passing the start of a segment the axis's mapping names (`segments:`), the
motion sets out from the last it passed, either way, and at rest from where
the run stands - whoever moves the axis, the hand or the program. Where the
mapping comes round its segments repeat every turn. Passing is again a
whole step, so the cards go out one by one without a jump: one long hand, a
throw across several targets, two quick swipes a wheel reads as one hand.
Should an arithmetic draw a whole step otherwise for another `from`, the
change travels as a change of the description does ([a change where the
parameters stand](#a-change-where-the-parameters-stand)), each view from where it was
shown. The run measuring the front view's unit is handed the `from` of the moment.

## Parameters of many axes

Parameters are a `LayoutParameters`: a struct of numbers, its axes listed as key
paths, and `Double` the parameters of one axis. An axis is a degree of freedom the
hand or the program moves on its own - how far a ring is turned, how near it
stands; how many dimensions the layout has is the arithmetic's, which may
read one axis for several things. The element wears all its parameters, one
lane an axis in the order `axes` names them: a part of a state is never
carried, so one state is one channel however many axes it has.

An axis the hand moves is moved alone: the arithmetic is handed the parameters
as their channel shows them, each axis a hand holds where it holds it, a snap
passed is named on that axis, and another axis traveling under the program
goes on beside the hand. `Double` parameters have one axis, `\.self`, which
`axis(range:keyframes:segments:periodic:)` and `Interaction.value(_:input:)`
name by themselves: an author writes the key path for parameters of several.

The type is inferred from the parameters lent, `parameters: $orbit`, which stands in
the same initializer as the arithmetic: every layout is lent its parameters, a
state of the application's - none of its own hidden from the program. Parameters
naming no axes is said.

## An axis

`.axis(_:range:keyframes:segments:periodic:)` says how the layout maps an
axis: how far the mapping runs (`range`), where its layout is worked out
(`keyframes`, [keyframes](#keyframes)), where its segments begin
(`segments`, [where a motion set out](#where-a-motion-set-out)) and whether
the mapping comes round (`periodic`) - the keyframes and the segments both an
`AxisValues`, places on the axis. It says nothing of the hand: what moves an
axis, how far, where it rests and how it goes on let go is the layout's one
`.interaction(_:)` ([interaction](interaction.md#on-a-motion-layout)), whose
range is the hand's own and may be another than the mapping's. The run works
on one record an axis (`Hand`), made of both: an axis the interaction moves,
mapped or not, and an axis mapped alone, which the program moves - the
arithmetic is asked at its keyframes, and the element's program hands the
host no value for it. A mapping with neither keyframes nor segments declares
nothing, and is said.

- THE RANGE is the hand's, not the program's: the hand moves the axis freely
  inside it and less and less past an end
  ([past an end](../host/interaction.md#past-an-end)); the program writes the
  axis anywhere. Wrapping, its length is the period and its upper end the
  lower one a turn on.
- THE SNAPS are places beside the range's ends, which always are: listed
  (`[1, 2]`, `.at(_:)`), a step from the lower end (`.every(_:)`), or none
  inside (`.endpoints`) - handed to the host lowest first, the upper end left
  out where the axis is periodic. NO SNAPS is an axis of its own kind: it
  rests wherever the hand or its throw leaves it, inside its range, and is
  going where the hand holds it meanwhile.
- ONE INPUT MAY MOVE SEVERAL AXES: each is a value of its own in the
  element's program - its hold, its throw and a swipe's grip kept by its lane
  - so a hand moving two axes moves each by its own unit, and let go, each
  rests its own way. Two axes the hand moves one across and one down are a
  pan: the host hears the hand every way and claims every first move.
- WHAT CANNOT MOVE IS SAID (`complain`) and moves nothing: an axis the
  parameters' `axes` do not list, a range with no end, a magnification's range
  reaching nought or told to come round, a swipe given no snaps, and what
  else an interaction is refused for ([interaction](interaction.md#what-is-refused)).

## Keyframes

An axis given `keyframes` has its arithmetic asked only there - at them, the
range's ends and every snap - and the poses between are blended view by
view, by identity. So quite different layouts - a ring at 0, a grid at 1, a
stack at 2 - are one `placements` answering a pose at each keyframe, and the
hand moves through them:

```text
  parameters 0 ─────────── 0.4 ─────────── 1 ─────────── 2
  asked      ring                          grid          stack
  shown      ring          ring→grid, 40%  grid          …
```

- ONE ARITHMETIC. There is no second closure: the keyframes only say where
  the engine asks the one it has. With none, it is asked every frame, as
  always.
- A REST IS THE AUTHOR'S TO KEYFRAME. The ends of the mapping's range are
  always keyframes; where the hand rests is the interaction's, another
  declaration, so a layout that should show the arithmetic's own answer
  wherever it rests names its snaps among its keyframes. Where a keyframe
  stands is not where the run rests unless it is a snap - a layout passes
  through a keyframe at 0.5 and rests at 0 and 1.
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
- ROUND AND PAST THE ENDS. On an axis that comes round, the parameters are taken
  into one turn; the keyframe at the turn's end is the arithmetic's own
  there, and a curve's neighbors across the seam are the next or the last
  turn's. Past an end, where the hand pulls the run, the end's two keyframes
  give a straight line that goes on, so the views still follow the hand. An
  axis of no length has one keyframe and no line: it is asked where it
  stands, as one with none is.
- WHAT A BLEND CANNOT KNOW. Between two keyframes a view goes the curve's
  way, not the arithmetic's: an arc becomes a chord (more keyframes, or a
  cubic), and arithmetic that jumps between neighboring keyframes - a card
  taken modulo round a strip, a `zIndex` flipping behind a ring - is drawn
  sweeping across. A size blended lays the view's content out every frame;
  a scale keeps it. On one axis the layouts are a sequence: from 0 to 2 the
  run passes 1. A switch between two layouts with nothing between them is a
  state the arithmetic reads, traveling as [a change at the current
  parameters](#a-change-where-the-parameters-stand).

### The curves

`LayoutInterpolation` is a scalar curve through knots: how many keyframes
either side of the two around a place it reads (`reach`), and the number at
the place. Every curve passes through each keyframe. The library's
`LayoutCurve`:

- `.linear` - straight, `reach` 0;
- `.catmullRom` and `.catmullRom(tension:)` - a cubic whose slope at a
  keyframe is the line through its neighbors, held by `1 - tension`: 0 the
  plain curve, 1 a stop at each keyframe; it may swing past one;
- `.monotone` - a cubic whose slope at a keyframe is limited so it never
  passes its neighbors (Steffen's: local, `reach` 1), so an opacity or a
  size never swings beyond its poses.

At an end of the range the slope is the straight line to the one neighbor.
A curve reading every keyframe - a natural spline - is not offered: its
poses could not be worked out lazily.

### Blending a pose

`LayoutBlend` blends one view's poses channel by channel along the curve:
the bounds (sizes at nought at least); the transform as its five drawn
numbers - move, turn, width and height - the turn unwrapped from keyframe to
keyframe the short way, and one transform at every keyframe left as it is;
opacity and shade inside 0...1, as a cubic overshoots, an unshaded layout
left unshaded. `zIndex` is blended as a number and the drawing order ranked
from it, equal numbers sharing a rank: two views swap as their numbers
cross rather than at half way.

## The hand

What the hand moves of the parameters is declared with the layout
(`interaction(_:)`, [interaction.md](interaction.md#on-a-motion-layout)) and
handed to the host as the element's program
(`ViewContract.interaction`, every view's); the hand itself is the host layer's -
the hold, the move, the rest, the throw
([the hand over a value](../host/interaction.md)). No scroller lies over the
views, so nothing bounds how far the hand goes, and the views under it
still answer a tap. The layout keeps no hand: its arithmetic is handed the
parameters where their channel shows them (`Run.live`), which under the
hand is where the hand holds them.

Two things of the hand stay the layout's, as its arithmetic alone knows
them. One is the front view's unit (`.frontItem`): how far the view drawn in
front goes for one unit of an axis where the run stands - of the views the
parameters move, the highest, then the one nearest the middle - measured by
the arithmetic a hundredth of a unit either side (`Run.measured`), which the
host asks through the layout's program (`HostLayoutProgram.frontItemUnit`).
The hand then carries that view with it, whatever size the room makes the
layout: a ring that grows with its window turns as far under the finger as
on a phone. A view standing still over the run - a dot, a caption - is no
front; with nothing moving, a room's length is a unit. A swipe asks it as
the run would rest on the snap it was taken at, a scroll where the run
stands at each move. The other is where a motion set out
([where a motion set out](#where-a-motion-set-out)), which stands while a
hand holds the run: the host says so (`HostLayoutProgram.handHolds`).

## A target named

A composed control keeping a value of its own by the parameters - a
gallery's position - is told where they are going as that changes
(`onNamed`, `Run.tellNamed`): the hand naming a snap, in the frame that
names it, or the program writing them. It is told the destination alone,
once a change, and nothing of the way there; the first frame learns where
the parameters stand and tells nobody.

## One view in the hand

`.itemDrag(begins:)` lets the hand take one view by itself rather than move
the run: by a first move across the layout's axis (`.across` - a card pulled
up out of a deck that scrolls sideways), or by a press standing still a long
press's time (`.held` - an icon lifted off a board). Which hand it is - the
run's, a view's or the page's - is the host layer's rule, one for every host
([the hand over a layout](../host/runtime.md#the-hand-over-a-layout)); a host
passes the press's point and decides nothing more. The element hears that
hand as an event of its own, `itemDragUpdated`: its phase, where it is in the
layout, how fast it goes - at the lift, as fast as it lifted - and how long
it has stood still - told again each long press's time it stands, so an
application can turn a board while an icon is held at its edge.

The core finds the view under the press from what the run last showed: the
one drawn on top - the highest `zIndex`, then the later - whose place, turned
as it is drawn about its middle, covers the point; a view drawn clear is
passed over. The held view is the third layer's: its middle where the middle
it was taken by has moved with the hand, over every other view - a run
standing at the highest rank an integer holds is ranked anew first, its order
kept, so nothing stands too high to be passed over. Everything
else of it is its place's, as shown, and the view's own: the application is
told as the hand takes it and as it lets it go (`ItemDrag.phase`), and lifts
it there by the view's own properties - `.scale` under the view's `.motion`,
a spring of its own - which the run never writes over; a hand that cannot
see its view lifted does not know it has it. Its place may change meanwhile
- the application moves its item in the order as the hand crosses a slot,
and the others travel to their new places as any change at the current
parameters do - but the held view stays under the hand, so it never leaves the
finger. The core tells which item that is (`ItemDrag.over`): the one whose
place stands under the hand, on top there, the held view passed over - the
places the arithmetic gives by the description as it stands, at the parameters
the run last showed, not where the views are drawn on their way, so the view
that made room, still traveling off from under the hand, never answers a
second time and swings the order back. An application reorders by the item
it is over and never works its own arithmetic backwards to a slot.

Let go, the difference between where it is shown and its place becomes a
change under the layout's motion, setting out at the hand's speed: the view
settles into its slot as a changed order would. With `.onItemDismissed`, a
view the hand took far enough one of its ways - or threw far enough, as a
throw of the input would carry it - flies on at the hand's speed, no slower
than the room's length a motion's length, and its item is told once it has
left the room; the application removes the item then. Every dismissal written
is a way out: the view leaves when it passed one, and each one it passed is
told, in the order written. The handler runs after the frame, as a job of the
UI thread, never inside the cycle.

