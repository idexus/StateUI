# Measured layouts

Some views place their children by arithmetic over a measurement rather than
by a layout the host knows: a frame report, a placed layout, a scroll read as
a number, and the gallery built from all three. The arithmetic runs in engines
on the host's frames, so a run of views can follow a finger with no view built.

```text
  GalleryView
   ├── ScrollReader: an empty ScrollView over the cards ──────▶ offset state ($scrolled)
   │     └── PlacedLayout (the cards) ◀── placements state ◀── engine(following: $scrolled, $room)
   │           └── .frame($room) ── the room, fed by the host ──┘   reads $scrolled.journey.value
   └── Turning: an empty view watching the asked position and shape
```

## Frame reports

`.onFrameChanged` reports the frame layout gave a view. It is called frame
because a frame is where a view sits in its parent's coordinates; bounds would
say the view's own.

One report carries every space. The host sends eight numbers - `x, y, width,
height, windowX, windowY, safeX, safeY`: the frame in the parent, the same
origin converted to the window, and the origin measured from where content can
safely sit - and each handler takes the four its space means. No property says
which space was asked for: the host computes all of them in one walk. A report
of any other length is a version mismatch, not an event, and reaches no
handler.

Nothing is measured unless something asks. A view without a handler is not
subscribed at all, the rule every reported property follows: a frame moves at
every measure, and a standing subscription per control would cost real work
for an answer nobody wanted.

A view reports when its own frame settles or moves - its first layout
included - when an ancestor's does, and when a scroll among its ancestors
moves it against the window. A view that asked about its frame listens to the
chain above it up to its page, attached on its first report and again
wherever a report finds its parent is no longer the one listened to, because
scrolling changes the window and safe-area answers without the view's own
frame moving. Each report is deduplicated against the last, so a layout pass
that writes four components is one report, and each handler deduplicates again
in its own space, so a parent-space listener hears nothing of a scroll. A
handler's memory starts afresh when the view is rebuilt, which costs one
repeated report that the handler's own state write absorbs.

Translation, rotation and scale are drawing transforms, not layout: an
animated translation reports nothing, while an animated width reports every
step of the layout it causes.

## Frame reader

`FrameReader` is composed over the modifier, and earns its place by what the
modifier cannot do: its content is built from the measurement. It holds the
last frame in a `@State` of its own, in a `Grid` that fills the offered space
and reports its own frame, so the closure runs again whenever the frame
settles somewhere new; the measurement arrives through the same channel as
every other report, and nothing about it exists in the host. Before the first
layout the closure is given a zero rectangle.

## A frame feed

`.frame($room)` writes the same frame into a state with no render at all: the
arithmetic that lays views out has it, and no view is built for it - the
difference from `FrameReader`, whose answer is a value the tree can show. Only
the host writes it; nothing this side writes reaches the platform, a view's
frame being the layout's answer.

## Sizes worked out from a measurement arrive

A size worked out from a measurement does not animate. Carried through a
motion it would crawl after every change of the measurement, and every step of
an animated size is a layout pass of the whole page, which starves the frame
clock every other animation runs on.

A layout that reports its frame - through `onFrameChanged` or a frame feed -
gives its children their new sizes at once while their places still animate,
since what a measurement reports is what the views beside a child leave it. A
size worked out from a room elsewhere wants `.motion(.none)`. A place worked
out from a measurement is written with no motion too: the room arrives over
several passes, and a place left to animate to its answer sets off from
whatever the first pass made of it - and where nothing else on the page moves
there are no frames to carry it the rest of the way.

## Placed layout

`PlacedLayout` is a run of views and an engine's arithmetic saying where each
goes and how it is turned. A fan, a ring, a spiral, a stack of receipts, a
masonry of tiles, a timeline and a gallery whose cards turn away as they leave
the middle are the same layout with different arithmetic.

```text
  engine(following: values)  ──▶  PlacedRun: one Placement per view, in order -
  on the host's frames               where it goes, how it is turned, its opacity,
                                     its shade, which is drawn over which
                                          │
  ZStack                                  ▼  the host writes each placement
   ├── Grid (wrapper)  ── the author's view   [ + the shade view, second ]
   ├── Grid (wrapper)  ── the author's view
   └── …
```

The arithmetic runs on the host's frames, never in a render: the engine reads
the values it follows, writes one placement a view, and the host wears them,
so a run of cards under a finger costs the sums and the writes and no
description at all. It is made of a ZStack and places in it, and it is one
frame late on its first
showing, because the room has to be measured before anything can be placed in
it.

Each view sits inside a container the host writes the placement onto, shaded
or not, which keeps the two writers apart: everything a placement says is
written onto the wrapper, so an author's own `.opacity` or `.rotation` on the
view beneath is theirs alone and never overwritten by a frame of arithmetic. A
shade is the wrapper's second child, which is how the host finds one; both
children are the library's own, so their order is its guarantee rather than
the author's. The absence of a shade is a number, `PackedPlacement.unshaded`,
because the host cannot see this side's views.

The motion belongs to the run. `PlacedRun(placements)` puts the views where it
says at once, which arithmetic re-run on every frame wants; a run written with
a motion animates there, so a shape that changes can cross while a finger goes
on moving the cards. `.motion(_:)` on the layout is what a run written
`.inherited` animates by, and it reaches the views' turn and fade as well as
their places.

A placed layout given no placement state places nothing: its views lie over
one another, each across the whole layout, as a ZStack's children do when they
name no area. It says so with a complaint, because the screen alone reads as a
view that failed to draw.

## Bounded arithmetic

The arithmetic owes one thing: on an axis nothing constrains, its answer has
to be bounded. A layout given no limit on an axis - inside a scroller - asks
for whatever its children reach, and a placement free to sit outside the room
then reaches further the more room it is given: the room grows the
placements, the placements grow the room, and the layout pass never settles.
Where the parent states a size there is nothing to watch for; where it does
not, the answer is capped. `GalleryView` holds a card to 1.375 times its
stated size for this reason.

## Scroll reader

`ScrollReader` lays an empty scroller over a run of views and reads its offset
into a state rather than showing it. What it holds is not scrolled: the views
stay where their own arithmetic puts them, and what moves is a number a
layout's engine follows. It is a scroller rather than a drag on purpose: a
finger drag, a two-finger trackpad swipe and a mouse wheel are one thing to a
scroller and three things to everything else, so all three move the run, with
the platform's own physics. Where the run comes to rest is the author's:
`onScrollStopped` hears the scroller stop, and a write to the offset carries it
on to the nearest item. How far it goes is how far beyond the room it scrolls,
so an author states the distance the arithmetic is written against rather than
a size that depends on the screen.

The views it holds take no touches: everything the user does belongs to the
scroller over them, so a tap or a drag is written on the reader itself.

The scroller's content has nothing to show, only a length: the room plus how
far the run goes beyond it. Across the axis it is one unit, never the room's
own size: a size taken from the room the scroller is in feeds itself, and a
measure that feeds itself need not settle. Where a tap is asked for, the
content is the room instead - the cell the scroller was given, which asks for
no more room than there already is - because a tap has to land on something: a
run swiped at a point answers no tap at that point when the content there is
one unit wide. The length is the content layout's own size, which the
scroller measures, rather than an extent a host would have to find among its
placements.

A tap on one part of the room - the card in front of the user - is answered by
a box in the content, which slides under the room. The box belongs at the
room's own place plus however far the run has scrolled, a number that moves on
the host's frames and is never described, so an engine following the offset
places it from where the run is, not where it is going, and places it at once.
Both boxes take the drag: the tap box lies over the length box, and a hand that
comes down on the card in front would otherwise be heard by nobody. A tap and a
drag on one view are two gestures, not a choice.

## Gallery view

`GalleryView` is a `PlacedLayout` for the cards, a `ScrollReader` for the hand,
and a state between them. The offset of the empty scroller over the cards is
written into a state no body reads, and the arithmetic placing the cards reads
it, so the run follows a finger, a trackpad and a wheel with no view built,
nothing compared and no message sent. The one render is the card crossing,
which tells the rest of the page which card the user is on.

The three shapes are three functions of the same numbers - which card, how
many, and the room - each answering where the card goes, how far it is turned,
how big it looks and how opaque it is. A change of shape is those values
changing. The shape is worn one render late, so there is a render in which the
cards are told they may animate before they are told where to - described in
one render, they would already be there - and for `crossing` milliseconds the
run is written to animate. The rest of the time placements arrive, since a
card a fifth of a second behind the hand is a card that lags.

- The middle card is named as the run passes halfway between two cards - under
  the hand, in the platform's throw, or on the way to a card - so a card
  crossed is one render and a frame is none. A position the scroller reported
  is where the run already is: it moves nothing, and the handler still hears
  it as it hears an assignment.
- The asked position is a closure, not a read: read in the gallery's body it
  would make that body a reader, and every card crossed would describe the
  whole deck for a picture none of them changes. The watchers are a view of
  their own beside the deck (composition.md, a watcher is a view of its own).
- A press is drawn on the view inside the card's wrapper, since the wrapper is
  written by the placement on every frame and a press there would be snapped
  away. The press shows and the card is back at its size before the tap's own
  work begins: opening a card usually builds a page, and a page built on the
  UI thread takes every frame beside it.
- On a desktop a pointer drag turns the run, because a mouse drag leaves a
  scroller where it stands; on a phone and a tablet the finger is the
  scroller's own gesture, and a pan beside it would move the cards twice. The
  form factor decides, not the platform. The drag writes the offset rather
  than the scroller: it is measured in the coordinates of a view inside the
  scroller's content, so scrolling while the hand is down would move the frame
  the report is measured in, and the two would chase each other. When the
  hand lets go, the scroller is snapped to where the run already is and then
  animates to the nearest card, rather than walking back to where the drag
  began.
- The run comes to rest on the nearest card: the scroller stops wherever the
  platform's throw leaves it, and a write to the offset carries it on under the
  element's motion.
- After each layout the run is put where the position says, asking again until
  it lands: a scroller cannot be moved before its content is laid out, and
  asked earlier it clamps to the length it has so far. That holds for every
  showing, since a scroller built afresh by a resize stands at nothing.

The sensitivity is one number, how far the hand travels to turn the run by one
card: three fifths of a card's width, far enough that the coarsest step a
device reports is part of a card, near enough that a deck is quick to cross.

The run is fitted to its room by a scale, not a rectangle. A card takes at most
half the room's width and stands within its height, the smaller answering, so
a taller window draws taller cards and a phone on its side is answered by the
height; the room needs 1.16 times a card's height for the fan's lift and a
turned card's corners. A card's rectangle stays its stated size, so its content
is laid out in the width the author wrote it for and drawn smaller, where a
shrinking rectangle would keep the words their size and cut them off. It grows
only to 1.375 times its stated size - past that the room is simply room, and
the run stands in its middle - which also keeps the arithmetic bounded.

Far cards go into the background by a fade or a shade. A card faded to a half
shows whatever is behind it, which in the wheel and the fan is the next card
rather than the page; a shade darkens what is there, and the card in front
wears none of it. With a shade the fade drops to a quarter: a card that only
darkens reads as lit differently rather than as further away, and a little fade
is what puts it behind. A strength out of range is held to 0...1 with a
complaint rather than refused, so a gallery still being written keeps working.

The wheel's turn is drawn flat, `ViewTransform.turn`, the same picture on every
platform (modifiers.md, turning out of the screen plane).
