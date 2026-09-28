# Journeys

A state is discrete, and its journey is part of it. Reading `fade` answers the
destination at once; `$fade.journey` is what happens between two destinations:
where the value is this frame, how fast it goes, and under what law. A value
that can have one conforms to `Walked`: a number, a point, a rectangle, insets,
a colour. Text has no half way, a whole number animated through rounding
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
  @State(motion: .custom)
      -> an engine of the application's writes value and velocity
  worn by nothing yet (no number issued)
      -> nothing animates it: a write lands at the destination at once
```

## Moving and waiting

`$x.journey.move(to:_:)` sends the value and suspends until it arrives. The
answer is true when it got there and false when something else ended the
journey: a newer destination, a value written over it, or a stop. Where there
is nothing to animate - already there, or the user asked for less motion - it
answers true at once.

The waiter is booked with the renderer under a negative id from the counter
every awaited act draws from, and the id is written into the completion lane;
nothing is queued, and the host answers by that id when the animation finishes
or is interrupted. The destination and completion lanes are forced dirty, so
sending a value where it is already going is still a fresh journey with a fresh
waiter. The write lands before the first suspension, so two moves started with
`async let` from one handler are booked in the order written. A given law stays
on the value: a plain assignment after `move(to: 0, .eased(2000))` animates for
two seconds too.

A state nothing wears lands at once and answers true: nobody would ever answer a
waiter booked on it. Under `.custom` the destination is written and the answer
is true at once, because the engine alone knows when it is done.

## Stopping

`stop()` raises the stop counter, leaving the value where the animation stood;
the host ends the animation and answers the waiter false. The waiter's id stays on
the image, because the host needs it to answer.

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

## Two reader sets

A body that reads `fade` is a reader of the state's storage and is asked when
the destination moves. A body that reads `$fade.journey.value` is a reader of
the image and is asked on every frame the host writes. So an animation costs a
build per frame exactly where somebody asked to see it move, and nothing where
a body reads the destination alone. `HostStorage.readAtBuild` is the image's
flag, set by the journey's reads, as `State.Storage.readAtBuild` is the
state's.

## Readings

A state has no cadence: it is at its value the moment it is written, so there
is no sweep on this side to hold back. What sweeps is where the value has got
to, which the host sends every cycle it moves. `.samples($fade, into: $shown,
.every(100))` copies it into an ordinary state at most ten times a second; the
body reads that state under the ordinary rules, and the source goes on costing
nothing. The window belongs to the reading, not the state: one source may be
read by two views into two states at two rates.

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
control reads it, and nothing is built. `.convertBack { $0 / 100 }` is the
engine the other way, for a control that reports, so the user's change lands
on the source in the source's terms. `convertBack` is meant as the inverse;
where it is not exactly - a rounding, a clamp - the source settles once on the
value the round trip lands on.

```text
  derived state   kept on the first source's storage under "file:line:column",
                  so a conversion written once is one state across renders
                  and the host's tie keeps its number
  sources         held WEAKLY by the conversion
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

The weak references break a ring. The derived state is kept on the first
source, and its conversion's arithmetic reads the sources; held strongly, the
source would keep the derived state, the derived state its conversion, and the
conversion the source, and no state of that view would ever be freed - every
visit to a page with a converted text leaving them behind, walked every frame.
What owns a conversion is the engine the differ arms for it, which hands its
number back when the element goes, and the binding it was made for.

## Many sources

`.multi($a, $b).convert { a, b in … }` is the same machinery over two to ten
states. `.multi` is a static member of `Binding`, so the leading dot resolves
against the type the control takes, and the call reads as the states and then
the arithmetic. The arities are written out one overload each: a parameter pack
captured in the escaping closure that reads the sources crashes the compiler,
and shorthand closure arguments have no arity to bind to over a pack. The
sources are read off their storage, not through their bindings, so the line
that wrote the conversion does not become a reader of every source.

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
  eased, already moving             the cubic Hermite of the same length, from
                                    the value and speed to the destination at rest
  spring                            about the distance left, so the three
                                    damping cases are the textbook ones
  still                             0.001 in the value's units and per ms: below
                                    any display's resolution for a colour
                                    channel (0 to 1) or a point
  longest                           a spring is over after 10 s, so no animation
                                    holds a display clock awake for ever
```

Time is in milliseconds, the unit of `Motion`'s numbers, so the law's velocity
is per millisecond; a journey reports per second, and an animator converts
where it reports. The slope of an eased curve is a central difference on the
curve, a function of progress alone, so it answers the same number in every
run.
