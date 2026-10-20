# Measured layouts

Some views place their children by arithmetic over a measurement rather than
by a layout the host knows: a frame report, a layout engine, and the gallery
built on one. The arithmetic runs in engines on the host's frames, so a run of
views can follow a finger with no view built.

```text
  GalleryView
   ├── LayoutEngine: the cards, the wheel's, fan's, row's or deck's
   │     arithmetic, the phase the card in front, a scroll the hand
   │     (layout-engine.md)
   └── Watcher: an empty view watching the asked position
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
moves it against the window. A view that asked about its frame says where it
stands on the display's next frame after anything was laid out or moved,
itself or not, because scrolling changes the window and safe-area answers
without the view's own frame moving; on the Web, what a call from the page
laid out says it as that call ends, before the browser draws. Each report is
deduplicated against the last, so a layout pass that writes four components is
one report, and each handler deduplicates again in its own space, so a
parent-space listener hears nothing of a scroll. A handler's memory starts
afresh when the view is rebuilt, which costs one repeated report that the
handler's own state write absorbs.

Translation, rotation and scale are drawing transforms, not layout: an
animated translation reports nothing, while an animated width reports every
step of the layout it causes.

## Frame reader

`GeometryReader` is composed over the modifier, and earns its place by what the
modifier cannot do: its content is built from the measurement. It holds the
last frame in a `@State` of its own, in a `Grid` that fills the offered space
and reports its own frame, so the closure runs again whenever the frame
settles somewhere new; the measurement arrives through the same channel as
every other report, and nothing about it exists in the host. Before the first
report the closure does not run and the reader holds nothing: content built
for a zero rectangle would stand at no size and grow when the frame came, and
a web engine keeps the height of a caption it measured at no width, a list
standing short under it.

## A frame feed

`.frame($room)` writes the same frame into a state with no render at all: the
arithmetic that lays views out has it, and no view is built for it - the
difference from `GeometryReader`, whose answer is a value the tree can show. Only
the host writes it; nothing this side writes reaches the platform, a view's
frame being the layout's answer.

## Sizes worked out from a measurement arrive

A size worked out from a measurement does not animate. Carried through a
motion it would crawl after every change of the measurement, and every step of
an animated size is a layout pass of the whole page, which starves the frame
clock every other animation runs on.

A layout whose frame, or a frame under it, is read - through `onFrameChanged`
or a frame feed - places every child at once, its size and its place alike:
each frame of an animation would hand the reader a room nobody chose. A
size worked out from a room elsewhere wants `.motion(.none)`. A place worked
out from a measurement is written with no motion too: the room arrives over
several passes, and a place left to animate to its answer sets off from
whatever the first pass made of it - and where nothing else on the page moves
there are no frames to carry it the rest of the way.

## Layout engine

A run of views placed by an application's arithmetic, worked out from a phase
the hand or the program moves, is a `LayoutEngine`: its element, its run, its
phase and its hand are layout-engine.md.

## Bounded arithmetic

The arithmetic owes one thing: on an axis nothing constrains, its answer has
to be bounded. A layout given no limit on an axis - inside a scroller - asks
for whatever its children reach, and a placement free to sit outside the room
then reaches further the more room it is given: the room grows the
placements, the placements grow the room, and the layout pass never settles.
Where the parent states a size there is nothing to watch for; where it does
not, the answer is capped. `GalleryView` holds a card to 1.375 times its
stated size for this reason.

## Gallery view

`GalleryView` is a `LayoutEngine` with the arithmetic of four shapes written,
its phase the card in front and its snaps one a card. The run follows a
finger, a trackpad and a wheel with no view built, nothing compared and no
message sent; the one render is the card crossing, which tells the rest of the
page which card the user is on. What the hand does - naming a card as the run
passes it, coming to rest on the nearest, a pointer's drag, a change of room -
is the layout engine's (layout-engine.md, the hand).

The four shapes are four functions of the same numbers - which card, how
many, and the room - each answering where the card goes, how far it is turned,
how big it looks and how opaque it is. The deck reads one more: where the
run's motion set out (layout-engine.md, where a motion set out), the card that
goes out the way the hand goes and tucks under the next, and it is swiped a
card at a time (layout-engine.md, a swipe); its cards behind are shaded, never
faded, as a faded one would show the card under it. A change of shape is read in the
gallery's body, so it is a change of the description: the cards land where the
new shape says.

- The asked position is a closure, not a read: read in the gallery's body it
  would make that body a reader, and every card crossed would describe the
  whole deck for a picture none of them changes. The watcher is a view of its
  own beside the deck (composition.md, a watcher is a view of its own).
- A press is drawn on the view inside the card's holder, since the holder is
  written by the placement on every frame and a press there would be snapped
  away. Only the card in front answers a tap, which activates it - handed to
  `onItemActivated` by its identity, as a list's item is; the press shows and
  the card is back at its size before the activation's own work begins:
  opening a card usually builds a page, and a page built on the UI thread
  takes every frame beside it. A tap is what activates a card: a composed
  view states no role a keyboard or a screen reader acts on
  ([accessibility and automation](modifiers.md#accessibility-and-automation)).
- A gallery nobody may swipe has no scroll: an assigned position places the
  cards there, and the card in front answers a tap itself.

The hand carries the card in front: it turns the run by one card as it travels
as far as that card moves for one, whatever size the room draws the run - the
layout engine's own unit ([the hand](layout-engine.md#the-hand)), with no
number of the gallery's.

The run is fitted to its room by a scale, not a rectangle. A card takes at most
half the room's width and stands within its height, the smaller answering, so
a taller window draws taller cards and a phone on its side is answered by the
height; the room needs 1.16 times a card's height for the fan's lift and a
turned card's corners. A card's rectangle stays its stated size, so its content
is laid out in the width the author wrote it for and drawn smaller, where a
shrinking rectangle would keep the words their size and cut them off. It grows
only to 1.375 times its stated size - past that the room is simply room, and
the run stands in its middle - which also keeps the arithmetic bounded. Until
the platform reports the room the run places no card: each stands as it is,
never drawn at a scale worked out from a room of nothing.

Far cards go into the background by a fade or a shade. A card faded to a half
shows whatever is behind it, which in the wheel and the fan is the next card
rather than the page; a shade darkens what is there, and the card in front
wears none of it. With a shade the fade drops to a quarter: a card that only
darkens reads as lit differently rather than as further away, and a little fade
is what puts it behind. A strength out of range is held to 0...1 with a
complaint rather than refused, so a gallery still being written keeps working.

The wheel's turn is drawn flat, `ViewTransform.turn`, the same picture on every
platform (modifiers.md, turning out of the screen plane).

## Position indicator

`PositionIndicator` is StateUI's composition of rectangles in a row, which
no host receives as a control of its own: UIKit and WinUI have a page
indicator, AppKit and Android's framework none, and GTK has none outside
libadwaita's carousel, so one composition serves all of them alike. Its count,
its position and its look are values of the composed view, and a value given
from a state is read in its content, so the row is built again when it
changes - a row of a few boxes, where a host-carried value would buy nothing.
The dots past `maximumVisible` are a run of that many holding the position as
near its middle as the ends allow (`PositionIndicator.shown`), so the current
dot is always drawn, and the run stands still only near the ends of the
sequence. A dot is a box as wide as it is tall, its corners half its size for
a circle, the gap between two dots the size of one. Being a composition, it
takes no `Style`: a style resolves into the node types a host receives.
