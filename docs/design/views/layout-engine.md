# Layout engine

`LayoutEngine` is the centre of a layout's motion: a run of views, the
application's arithmetic that places them on the host's frames, the phase the
arithmetic is worked out from, and the hand that moves the phase. A ring, a
fan, a wheel of cards, a timeline and a gallery are one layout with different
arithmetic; `GalleryView` is one with the arithmetic of three shapes written.

```text
  LayoutEngine - the element, a host's ZStack, wearing the phase   ◀── the host walks it
   ├── holder ── the author's view [ + the shade, second ]   ◀─┐
   ├── …                                                       │  one run of placements,
   └── scroller: an empty ScrollView over the views ───────────┘  written by the engine
         └── content: its length, and a box under each view       on the host's frames
         engine(following: room, phase, scrolled, length, followed…)
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

The run places every child, the library's own too: the views in the items'
order, then the scroller over them across the whole room.
A host lays out by arithmetic only the children a run leaves unplaced, so one
run for all of them keeps every host's ZStack to the one rule it already has.

## The run

The arithmetic runs on the host's frames, never in a render: whenever the
room, the phase - written by the program or walked by the host - the
scroller's offset, its laid-out length or a state named in `following(_:)` is
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
nothing. The hand acts all the same, so a scroll reported before the room is
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
destination at once, which would make a ring jump. With a scroll at rest the
phase is where the scroller is, held between the lowest and the highest snap
target. Until the scroller reports its first layout its offset is nobody's:
the run stands where the phase says and names nothing, so a layout starting
on its third target starts there rather than naming the first.

The phase lent is a state, `$turn`: a binding worked out from others has no
image to wear, so its phase would jump where it is sent, and the layout says
so once. The engine follows the phase itself, so a new one wakes the arithmetic and
builds nothing: a destination the run did not name is the program's, and
becomes where the run stands should the room change.

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
the scroller stands, a target passed is named on that axis, and the scroller
mirrors a journey of that axis only - another axis travelling under the
program leaves the hand leading its own. `.input(_:)` is a `Double`
phase's, whose one axis is `\.self`.

The type is inferred from the phase lent, `.phase($orbit)`, which stands in
the same expression as the arithmetic; a layout lent none takes its own,
started at `init()`. A phase naming no axes is said.

## The hand

A scroll is an empty native scroller over the views, its offset in points the
hand's axis times `pointsPerUnit` from the lowest snap target on that axis. It is a scroller
rather than a drag on purpose: a finger drag, a two-finger trackpad swipe and
a mouse wheel are one thing to a scroller and three things to everything else,
so all three move the run with the platform's own physics. A scroll needs
snap targets on its axis, which say how far it runs; one given none lays no
scroller and says why.

The views under a scroll take no touches: everything the user does belongs to
the scroller over them. The scroller's content has nothing to show, only a
length - the room plus how far the run goes beyond it. Across the axis it is
one unit, never the room's own size: a size taken from the room the scroller
is in feeds itself, and a measure that feeds itself need not settle. Where a
tap is asked for the content is the room instead, because a tap has to land on
something. The length is the content's own size, which the scroller measures,
reported back as laid out (`length`): that is when the scroller can hold what
a new room asks.

- While the phase travels the scroller follows it, snapped each frame where
  the phase stands: it never travels on its own, so the scroll and its
  arithmetic cannot part, and on the way the program sent the run nothing is
  named - the phase is where it goes, and naming what it passes would turn it
  back and forth. A hand moving the scroller on that way takes the run: the
  journey stops, and the phase is named where the hand holds it.
- Otherwise the scroller leads, and the phase is named as the run passes
  halfway between two snap targets, under the hand or in the platform's
  throw: one render a target, none a frame. A name is a reading of the hand
  (`journey.snap(to:)`), not a journey.
- At rest the phase is set where the scroller stopped and travels on to the
  nearest target, a journey of its own the scroller follows.
- On a desktop a pointer drag moves the run, because a mouse drag leaves a
  scroller where it stands; on a phone and a tablet the finger is the
  scroller's own gesture, and a pan beside it would move the views twice. The
  form factor decides, not the platform. The drag is heard on the scroller
  itself, which spans the room and stands still while its content slides: heard
  on the content, it would be measured in a frame the run moves under the hand,
  and its report would chase itself - a drag to the left turned the run back.
  When the hand lets go, the run travels on to the nearest target as at rest.
- A tap lands on a box under each view as it is drawn - its bounds taken
  through its scale about the middle, and moved - in the content, which slides
  under the room, so the box stands at the view's place plus however far the
  run has scrolled. The boxes are ranked as the views, so the platform's own
  hit test finds the one drawn on top. With no scroll the view itself answers.

## Coming to rest

When the hand lets go the run travels on to where it comes to rest, from
where the scroller stopped, as one journey of the phase. Two ways say where
that is, and both may stand on one layout:

- `.snap(\.axis, to:)` gives an axis targets of its own. It is independent:
  it rests on the nearest of them, and only its own hand moves it there - a
  settle of another hand leaves it where the program put it.
- `.snapTargets([...])` lists whole phases, the combinations allowed. The
  nearest is the one at the least distance over the axes without targets of
  their own, every one of those axes travelling to it; of two as near, the
  first listed. A `Double` phase's targets are of this kind.

Under the hand only the hand's axis is named - the nearest place on it any
target names - so an axis the hand does not drive never jumps as the scroll
passes; the whole combination is reached at rest.

## A change of room

After each layout of the scroller the run is put where the phase says; a
scroller not laid out yet keeps the offset for its first layout (host/layout.md,
an offset the tree writes). A change of room keeps where the run stood: a room
grown wider - a phone turned - stands the scroller in it before the run is as
long as the room asks, so the toolkit clamps the offset and reports a phase
short of it. The layout names its phase again and, once the scroller says its
run is long enough to hold it, sends the run there; until then the hand names
nothing and a rest is no phase the user chose.
