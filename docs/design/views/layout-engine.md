# Layout engine

`LayoutEngine` is the centre of a layout's motion: a run of views, the
application's arithmetic that places them on the host's frames, the phase the
arithmetic is worked out from, and the hand that moves the phase. A ring, a
fan, a wheel of cards, a timeline and a gallery are one layout with different
arithmetic; `GalleryView` is one with the arithmetic of three shapes written.

```text
  LayoutEngine - the element, a host's ZStack
   ├── holder ── the author's view [ + the shade, second ]   ◀─┐
   ├── …                                                       │  one run of placements,
   ├── scroller: an empty ScrollView over the views ───────────┤  written by the engine
   │     └── content: its length, and a box under each view   │  on the host's frames
   └── watcher: a view of nothing reading the phase asked  ────┘
         engine(following: room, asked, scrolled, length, followed…)
```

## The element

The layout is an element of its own, `LayoutEngineContract`, which every host
stands on its ZStack: children one over another, each where a run of
placements on the element's own `area` puts it, or in the whole room until a
run comes. It is the element an author's modifiers reach - a background, a
border, a clip - so the node its contract describes is the one the author
writes on, and its row in the matrix is proven by its own family.

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
order, the scroller over them across the whole room, the watcher at no size.
A host lays out by arithmetic only the children a run leaves unplaced, so one
run for all of them keeps every host's ZStack to the one rule it already has.

## The run

The arithmetic runs on the host's frames, never in a render: whenever the
room, the phase asked, the scroller's offset, its laid-out length or a state
named in `following(_:)` is written, and once after every render that
describes the layout. It is handed the room at the layout's own origin and the
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
the hand names it. The arithmetic is handed it as it stands each frame - with
a scroll, where the scroller is, held between the lowest and the highest snap
target. Until the scroller reports its first layout its offset is nobody's:
the run stands at the phase asked and names nothing, so a layout starting on
its third target starts there rather than naming the first.

The watcher reads the phase asked in a view of its own, so a new phase
rebuilds the watcher and nothing about the views. It sends the run there: the
scroller, to travel under the layout's motion, or, with no hand, the
arithmetic again. A phase the hand named and the program reads back moves
nothing.

## The hand

A scroll is an empty native scroller over the views, its offset in points the
phase times `pointsPerUnit` from the lowest snap target. It is a scroller
rather than a drag on purpose: a finger drag, a two-finger trackpad swipe and
a mouse wheel are one thing to a scroller and three things to everything else,
so all three move the run with the platform's own physics. A scroll needs its
snap targets, which say how far it runs; one given none lays no scroller and
says why.

The views under a scroll take no touches: everything the user does belongs to
the scroller over them. The scroller's content has nothing to show, only a
length - the room plus how far the run goes beyond it. Across the axis it is
one unit, never the room's own size: a size taken from the room the scroller
is in feeds itself, and a measure that feeds itself need not settle. Where a
tap is asked for the content is the room instead, because a tap has to land on
something. The length is the content's own size, which the scroller measures,
reported back as laid out (`length`): that is when the scroller can hold what
a new room asks.

- The phase is named as the run passes halfway between two snap targets, under
  the hand or in the platform's throw: one render a target, none a frame. On a
  way the program sent the run it names nothing - the phase is where it goes,
  and naming what it passes would turn the phase back and forth.
- At rest the run travels on to the nearest target, under the layout's motion.
- On a desktop a pointer drag moves the run, because a mouse drag leaves a
  scroller where it stands; on a phone and a tablet the finger is the
  scroller's own gesture, and a pan beside it would move the views twice. The
  form factor decides, not the platform. The drag is heard on the scroller
  itself, which spans the room and stands still while its content slides: heard
  on the content, it would be measured in a frame the run moves under the hand,
  and its report would chase itself - a drag to the left turned the run back.
  When the hand lets go, the scroller is snapped to where the run is and
  travels on to the nearest target.
- A tap lands on a box under each view as it is drawn - its bounds taken
  through its scale about the middle, and moved - in the content, which slides
  under the room, so the box stands at the view's place plus however far the
  run has scrolled. The boxes are ranked as the views, so the platform's own
  hit test finds the one drawn on top. With no scroll the view itself answers.

## A change of room

After each layout of the scroller the run is put where the phase says; a
scroller not laid out yet keeps the offset for its first layout (host/layout.md,
an offset the tree writes). A change of room keeps where the run stood: a room
grown wider - a phone turned - stands the scroller in it before the run is as
long as the room asks, so the toolkit clamps the offset and reports a phase
short of it. The layout names its phase again and, once the scroller says its
run is long enough to hold it, sends the run there; until then the hand names
nothing and a rest is no phase the user chose.
