# Journeys

A state is discrete, and its journey is part of it. Reading `fade` answers the
destination at once; `$fade.journey` is what happens between two destinations:
where the value is this frame, how fast it goes, and under what law. A value
that can have one conforms to `Walked`: a number, a point, a rectangle, insets,
a color. Text has no half way, a whole number animated through rounding
stutters, and a truth value has two places and no distance, so none of them is
`Walked`; a placement run already carries a law for the whole run.

## The journey lanes

A value the host animates lies on its image as `JourneyLanes`, the shape a
host's animation is fed from, read through `HostBoundary.journey(from:)`:

```text
  value        w lanes   where it IS; the host writes it every frame it moves,
                         so value == destination means "arrived"
  destination  w lanes   where it is GOING: the state's own value
  velocity     w lanes   per second, lane by lane; a finger's report sets it to
                         nought, a write from this side is a kick
  law          3 lanes   StateLaw: [kind, millis, curve or damping]
  completion   1 lane    the negative id a waiter is registered under, or 0
  stopped      1 lane    how many times an animation stopped - a counter, so two
                         stops in a row are two changes
                         (w = the value's own lane count; 3w + 5 in all)
```

One of these is one state channel on the host however many controls are handed
`$fade`: each control holds a handle on the one value, written from the same
lanes on the same frame, so two controls on one state can never stand in two
places, and a control handed the state mid-animation joins it where it is.

## The law on the image

```text
  kind 0  none (an eased law of no length)
  kind 1  inherited - the element's own, resolved at each crossing
  kind 2  eased:  millis, curve (Easing's number)
  kind 3  spring: response millis, damping
  kind 4  custom  - an engine on this side animates the value
```

`.none` and `.inherited` cross as themselves rather than as an eased law of no
length. `.inherited` is a request, not a reading: the image goes on saying what
the author wrote, and `HostStorage.crossing()` replaces it with the element's
resolved law on every read the host makes. Resolving it once at the write would
freeze whatever the application said at declaration onto a value an element
claims later. The element's law is resolved by the differ, which alone can read
an element's per-kind motion plan (identity-and-diffing.md).

Under `.custom` the host animates nothing: the crossing hands it `.none` and a
destination equal to wherever this side's engine last wrote the value, so the
host wears each frame as it comes, and a destination the author wrote - which
the engine reads, and the host never sees - sends the host nowhere.

`@State(motion:)` puts the law on the value from the first frame; it is the
first answer the crossing asks for, ahead of the element's `.motion(_:)`, the
application's and the library's. `$x.journey.motion` changes it later, except
`.custom`, which says who animates the value and is settled at the declaration:
the host is told at the first crossing and cannot be told again.

## Who animates it

```text
  handed to a driven modifier, a two-way control or a scroller
      -> the HOST animates it and writes value and velocity back every frame
  @State(animatedBy: .engine)
      -> an engine of the application's writes value and velocity
  worn by no live element (no tie, number or not)
      -> nothing animates it: a write lands at the destination at once
```

## Moving and waiting

`$x.journey.move(to:_:)` sends the value and returns its `Arrival` at once;
`arrived()` suspends until the value arrives. It has two spellings, one with a
law and one without (`move(to:)`, under the value's own), and no optional
law: `.none` written there is always the law that does not move, which a law
that defaults to nil would read as "none given". A move is a write of the
destination: admitted as one (`Storage.admits`, state.md - a destination the
state refuses is no journey, and the arrival answers false), the state reads
the target at once, its readers are built again
and a kept state keeps it, as after an assignment (`Storage.moved(to:)`) - and
the journey the host walks is the move's, on its law, never a second one on the
value's own. A stop, in turn, comes back as a write of where the value stood:
the host makes that its destination and reports it. The answer is true when it got
there and false when something else ended the journey: a newer destination, a
value written over it, or a stop. Where there is nothing to animate - already
there, or the user asked for less motion - it arrives on the host's next frame
and answers true.

The waiter is booked with the renderer under a negative id from the counter
every awaited act draws from, and the id is written into the completion lane;
nothing is queued, and the host answers by that id when the animation finishes
or is interrupted. The completion lane is forced dirty, and the destination
lanes are forced too where none of them changes, so sending a value where it
is already going is still a fresh journey with a fresh waiter. Where some
lanes change, only they are laid: the host sends those lanes on as one run
under the waiter, and a lane the move leaves alone travels on as it was
(host/motion.md, a channel lane by lane). The write and the booking land before `move` returns, so moves sent one after
another and awaited after are in the air together, booked in the order
written. A given law is that move's alone: the value keeps its own
(`@State(motion:)`, `journey.motion`) in its storage, the move lays the law it
was given on the lanes for its travel, and the next write that names none - an
assignment, or a move without a law - lays the value's own back with its
destination, so a plain assignment after `move(to: 0,
.eased(.milliseconds(2000)))` travels on the value's own law.

Each waiter waits under a number of its own. A task cancelled while it waits
stops waiting with `CancellationError` - its run may be superseded, its element
gone - and leaves alone: the movement goes on for every other waiter, and
`stop()` is what ends it. Every resume - the end, a failure, a cancellation -
is counted as it is made and taken back as the waiter runs again, so a host
waiting for the queue to go quiet never waits on a failure answered.

A state nothing wears lands at once and answers true: nobody would ever answer a
waiter booked on it. Under `.custom` the destination is written and the answer
is true at once, because the engine alone knows when it is done.

## Stopping

`stop()` raises the stop counter, leaving the value where the animation stood;
the host ends the animation and answers the waiter false. The waiter's id stays on
the image, because the host needs it to answer. The color pair the state kept
is let go: the value stands at a color between two, which no pair names, and
a render laying the pair again would send the host on to it.

## Writing the parts

```text
  journey.value = v        a snap of what is shown: the destination stays, so a
                           destination left behind sends the host straight back;
                           under .custom it is the engine's frame
  journey.velocity = v     a kick: it bends an animation under way, and takes a
                           still value out and lets the law bring it back
  journey.snap(to: v)      value, destination and a still speed together, at
                           once - for a value worked out rather than chosen
  state = v                the destination: a journey to somewhere new
```

A value worked out from a measurement or a report is not a destination, and
animated as one it crawls after the thing that decided it; `snap(to:)` is its
write. It is synchronous: nothing is booked and nobody waits.

Each write lays the lanes of its own parts and leaves every other lane as it
lies, bit for bit. A value read back through its type is not always the lanes
it came from - a color is eight bits a channel, and the host reports the
frames between them - so a stop or a move laying the whole journey again would
say the value and its speed moved, and the host would start over from them
(`JourneyTests.testAJourneyWriteLaysOnlyItsPart`).

## One part at once

A motion layout names the target its hand passes on one axis of its parameters,
which another hand or the program may be moving: `Journey.snap(_:to:)`, the
library's own, puts one part of the value - a key path to one of its numbers -
where it is at once, as `snap(to:)` does the whole. Its lanes of value,
destination and speed are laid and no other, so the host takes that lane out
of the run it traveled in and leaves the rest going.

## Two reader sets

A body that reads `fade` is a reader of the state's storage and is asked when
the destination moves. A body that reads `$fade.journey.value` is a reader of
the image and is asked on every frame the host writes. So an animation costs a
build per frame exactly where somebody asked to see it move, and nothing where
a body reads the destination alone. `HostStorage.readAtBuild` is the image's
flag, set by the journey's reads, as `State.Storage.readAtBuild` is the
state's.

## Where a run shows it

A layout's run moves its parameters under the hand, a throw or an approach in the
core, not as a walk of the host's: the hand names each target it passes, and
the state's own value stays that target, so a body reading it rebuilds only
as a target passes. Where the run is shown meanwhile is the journey's value:
the run tells the storage (`show(_:by:)`) each frame it moves, and once it
rests lets go of it. That moves the state's stamp and asks the journey's
readers - an engine following the parameters, another layout wearing them, a body
reading `journey.value` - and not the state's own readers. Nothing of it
reaches the host, which walks the target; what the run shows is the core's,
told under the run's own name, so only the run that showed it lets go of it.

## Readings

A state has no cadence: it is at its value the moment it is written, so there
is no sweep on this side to hold back. What sweeps is where the value has got
to, which the host sends every cycle it moves. `.samples($fade, into: $shown,
.every(.milliseconds(100)))` copies it into an ordinary state at most ten times a second; the
body reads that state under the ordinary rules, and the source goes on costing
nothing. The window belongs to the reading, not the state: one source may be
read by two views into two states at two rates, taken in the order asked.

```text
  a frame lands   due():  now        -> take it, the window starts here
                          waitUntil  -> book one reading for the window's end
                          waiting    -> one is booked already and covers this
```

A reading whose window has not passed books one for the end of it, so the last
frame of an animation arrives. It stops by itself: a take copies only what
changed, and the host stops sending when the channel stops moving. The booked
reading sleeps with `Task.sleep`; nothing here uses a run-loop timer.

The window has to survive the render the reading's own write asks for. That
render walks the very view that asked for the reading; made afresh there, the
window would start over, the next frame would count as a first, and a reading
at any rate would be taken every frame. So a standing reading at the same rate
is handed the new render's closure and kept; a changed rate is a new reading.

A reading belongs to the element that asked for it. The image knows it weakly
and the element (`RenderedNode.readings`) holds it: kept strongly by the image,
state, image, reading and closure would form a ring, no state of that view
would be freed, and the board would walk every leftover reading every frame.

## Conversions

`$volume.convert { $0 * 100 }` is a second state the host carries, worked out
from the first by an engine the differ writes: whenever the source moves, the
engine runs on the display's frames and settles the derived value where the
control reads it, and nothing is built. `back: { $0 / 100 }` beside it is the
engine the other way, for a control that reports, so the user's change lands
on the source in the source's terms. It is woken by the host's reports alone
(`HostStorage.reports`), never by the forward engine settling the derived
value: what the application writes goes forward and stays as written - `v =
0.123` through a slider converting by hundredths stays 0.123, the control
showing 12 - as the application's writes never come back as the user's.
The way back is meant as the inverse; where it is not exactly - a rounding, a
clamp - a report lands on the source as the round trip makes it. It is written
in the same call, `convert(_:back:)`, typed `(Out) -> Value`: a way back
answering another type does not compile, and one call declares the conversion
whole - a way back that comes and goes stays one call, `back: editing ? { … } :
nil`, so the derived state stays the same object.

```text
  derived state   known to the first source's storage under a key spelled
                  nowhere (DerivationKey): the element being built and the
                  call's file, line and column (PathNumber), the identities of
                  the ForEach rows it stands in - values, compared as values -
                  and which time that line ran in the build; held by that
                  element as it holds its readings: one state per use across
                  renders - the host's tie keeps its number - so two views
                  converting one source on one line keep two, each row of a
                  ForEach its own, kept with its row as the rows move, and a
                  helper called twice two, told apart by its place in the
                  build as a view without an id is; an element that leaves
                  takes its own; made with no element being built, the source
                  holds it, worked out at once - its arithmetic reads the
                  source, which would otherwise hold what holds it
  sources         each the storage its binding was made from, held, asked for
                  the one it stands for - itself, or the one it was given up for
                  at an adoption while that stands (state.md, storage and box)
  engines         back (priority -2) first, then forward (-1), both ahead of
                  every author's engine, on the element wearing the result
```

Handing a conversion on reads nothing. A body that reads one reads its sources:
the value is worked out afresh on the read and the body becomes every source's
reader.

The back engine runs first because a report is the newer word; the forward one
then derives again from what it landed. Otherwise a report arriving in the very
cycle the engines first run would be derived over by sources it has not
reached.

No ring closes. The derived state is kept on the first source, strongly where
no element was being built, and its conversion's arithmetic holds the sources;
were the derived state to hold its conversion too, the source would keep the
derived state, the derived state its conversion, and the conversion the source,
and no state of that view would ever be freed - every visit to a page with a
converted text leaving them behind, walked every frame. So the derived state
knows its conversion weakly, and the value a source holds is worked out at
once, its making closure let go. What owns a conversion is the engine the
differ arms for it, which hands its number back when the element goes, and the
binding it was made for.

## A chain of conversions

A conversion of a conversion - `$volume.convert { $0 * 100 }.convert { "\(Int($0))%" }`
- is worked out from the first sources. Each conversion holds the ones its
sources are the derived side of (`upstream`), since the middle of a chain has
no binding of its own once the expression writing it ends; the element wearing
the last writes the engines of every link, the first sources' first, each
conversion once, so a write to the first source goes through the chain in one
cycle. A body reading the last reads every link's sources, and works each link
out over the one before it. A report goes back the same way: each link's
way back lands it on its sources and hands it to the link before.

## A conversion declared again

A conversion is one object across renders, and each render declares it again:
its sources, its arithmetic and its way back are the new declaration's alone.
A body that wrote `back:` before and does not now leaves no way back -
the control's reports go back to nobody - and one writing it again takes only
the reports made from then on, so a report made while there was none never
lands later (`Conversion.declareAgain`, `declareBack`).

## Many sources

`.multi($a, $b).convert { a, b in … }` is the same machinery over two to ten
states. `.multi` is a static member of `Binding`, so the leading dot resolves
against the type the control takes, and the call reads as the states and then
the arithmetic. The arities are written out one overload each, because no
parameter pack says "two or more" (measured on Swift 6.4): a pack alone reads
every spelling, `$0` included, but takes `.multi()` - no source, a stop at run
time - and `.multi($a)`, a second road to `$a.convert`, and nothing refuses
either; a pack after two named sources leaves its empty tail uninferred, so
the commonest call, two sources, does not compile. The overloads refuse both
at compile time. The sources are read off their storage, not through their bindings, so the line
that wrote the conversion does not become a reader of every source. Two
states take a way back as one does, `.multi($a, $b).convert(_:back:)`, the way
back answering both, each in its own type.

## Motion laws

`HostMotionLaw` gives where an animation stands at a time since it began. Every
runtime animates with these numbers by calling it, and `MotionLawTests` holds
every animation of its table to where it starts and where it lands.

```text
  closed form in the elapsed time   nothing is integrated frame by frame, so a
                                    run of frames gives the same numbers at any
                                    frame rate, a hand-wound clock reproduces
                                    them, and a suspended application slews to
                                    the end rather than resuming mid-air
  velocity                          the law's own derivative, never a difference
                                    of two samples; a new animation starts from
                                    the speed the old one reached, so a new
                                    destination bends the value
  eased, from standstill            the curve itself
  eased, already moving             the curve bent by p(1 - p)²: it sets out at
                                    the speed it had and lands where the curve
                                    does - at the curve's own starting speed the
                                    curve itself, overshoot and all
  spring                            about the distance left, so the three
                                    damping cases are the textbook ones
  still                             0.001 in the value's units, and 1 a second
                                    for a speed: below any display's resolution
                                    for a color channel (0 to 1) or a point
  longest                           a spring is over after 10 s, so no animation
                                    holds a display clock awake for ever
```

Time is in milliseconds, the unit a `Motion` keeps its length in, and a speed
is per second everywhere - told to the law, answered by it, carried by an
animation and reported by a journey - the law alone working in milliseconds
inside, so no animator converts. The slope of an eased curve is a central difference on the
curve, a function of progress alone, so it answers the same number in every
run.
