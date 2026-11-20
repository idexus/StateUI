# Journeys

A state is discrete: reading `fade` answers the destination at once, and
writing it sends the value there. Its journey, `$fade.journey`, is a handle to
how a host shows the value between two destinations. The handle owns nothing
and starts nothing. A value that can have one conforms to `Walked`: a number,
a point, a rectangle, insets, a color. Text has no half way, a whole number
animated through rounding stutters, and a truth value has two places and no
distance, so none of them is `Walked`.

Of a moving value's three owners
([architecture](../architecture.md#a-moving-value-has-three-owners)) the core
is the first: it holds the destination, and of where the value stands only
what the host layer reported.

## The journey lanes

A value the host animates lies on its image as `JourneyLanes`, the shape a
host's animation is fed from, read through `HostBoundary.journey(from:)`:

```text
  value        w lanes   where it stands, as the host last said
  destination  w lanes   where it is going: the state's own value
  velocity     w lanes   per second, lane by lane
  law          3 lanes   StateLaw: [kind, millis, curve or damping]
  completion   1 lane    the negative id a waiter is registered under, or 0
  stopped      1 lane    how many times an animation stopped - a counter, so two
                         stops in a row are two changes
                         (w = the value's own lane count; 3w + 5 in all)
```

One of these is one state channel on the host however many controls are handed
`$fade`: each control holds a handle on the one value, written from the same
lanes on the same frame, so two controls on one state can never stand in two
places.

## A channel's life

A channel exists while the state has a consumer: a property of a live element
showing it, an engine following its journey, or a reading of it. The core
counts them on the image (`HostStorage.consumers`); the host layer counts the
same ones ([motion in the runtime](../host/motion.md#state-channels)).

```text
  no consumer          a value and a motion; no sample, no speed, nothing to wait for
  the first consumer   a channel of a new generation, at the destination, still
  another consumer     joins the channel where it stands
  one of several goes  the rest go on
  the last one goes    a movement under way ends `.detached`; the sample goes
  attached again       a new generation; nothing of the last one comes back
```

The count changes element by element as a tree is walked, and is settled once
the walk is done (`Differ.settleChannels`): a consumer that leaves one element
for another in the same walk never closes the channel. As a channel closes the
image is laid at its destination, still, so the next channel starts there and
replays nothing it did not see.

An element's driven properties tie it to their states; the journeys its
engines and readings follow with no property are told to the host apart, in
`HostPatch.followed`, so the host carries a channel for a state nothing draws.

The trap is a getter that makes a channel. Reading `sample`, `motion` or
`reach(_:)` makes no image and asks for no cycle, so a thousand handles cost
nothing (`ChannelLifetimeTests`).

## The sample

`journey.sample` is the host's last report of the channel, whole: where the
value stands, the destination the channel is taking it to, and its speed, with
the time of the display's frame it is read on. It is nil where the state has no
channel.

```text
  sample.value         where the host shows it
  sample.destination   the destination the channel had taken; the state's own
                       value may be a newer one waiting for its frame
  sample.velocity      per second, lane by lane
  sample.time          the frame's time, shared by every sample read on it
```

The core keeps the report as `HostStorage.sample`, set by
`Renderer.hostReported` from the channel's own word and never pieced together
from lanes this side wrote since. It carries no time of its own: a channel
standing still is the same sample on every frame and wakes nobody; the time
handed out is the board's `frameTime`, the latest frame the core heard of.

## Two reader sets

A body that reads `fade` is a reader of the state's storage and is asked when
the destination moves. A body that reads `$fade.journey.sample` is a reader of
the state's `PresentationWatch` and is asked when the sample changes, comes or
goes. So an animation costs a build per frame exactly where somebody asked to
see it move. The watch is made at the first such read; it is no image and
keeps no channel.

The same watch is what an engine following the journey compares
([what wakes an engine](cycle.md#what-wakes-an-engine)).

## Which motion

A channel with the host's animator travels under, in order:

```text
  the motion given to `move(to:_:)`     that move's alone
  the state's own                       `@State(motion:)`, `journey.setMotion(_:)`
  the application's                     `ApplicationSession.motion`
  `Motion.standard`
```

No receiver decides it: a channel is every receiver's, so an element's
`.motion(_:)` says how that element's described properties travel and nothing
about a state it shows. `.inherited` on the image is a request the crossing
answers with the application's motion on every read (`HostStorage.crossing()`,
`inherited`), so a change of the application's reaches a value already
standing.

`setMotion(_:)` changes what the next destination travels under. It lays
nothing on the image: a movement begun keeps the motion it set out under.

## The law on the image

```text
  kind 0  none (an eased law of no length)
  kind 1  inherited - the application's, resolved at each crossing
  kind 2  eased:  millis, curve (Easing's number)
  kind 3  spring: response millis, damping
  kind 4  custom  - an engine on this side animates the value
  kind 5  glide:  longest millis - on from the speed it was handed
```

Under `.custom` the host animates nothing: the crossing hands it `.none` and a
destination equal to wherever this side's engine last put the value, so the
host shows each frame as it comes, and the destination the author wrote -
which the engine reads, and the host never sees - sends the host nowhere.

## Who animates it

```text
  shown by a driven modifier, a two-way control or a scroller
      -> the HOST animates it and reports where it stands every frame
  @State(animatedBy: .engine)
      -> an engine of the application says where it stands
  no consumer
      -> nothing animates it: a write is the whole of it
```

## Moving and waiting

`$x.journey.move(to:_:)` sends the value and returns its `MotionRun` at once.
It has two spellings, one with a motion and one without, and no optional
motion: `.none` written there is always the motion that does not move. A move
is a write of the destination: admitted as one (`Storage.admits`, state.md),
the state reads the target at once, its readers are built again and a kept
state keeps it (`Storage.moved(to:)`).

The waiter is booked with the renderer under a negative id from the counter
every awaited act draws from, and the id is written into the completion lane;
the host answers by that id when its run ends. The completion lane is forced
dirty, and the destination lanes are forced too where none of them changes, so
sending a value where it is already going is still a fresh movement with a
fresh waiter. Where some lanes change, only they are laid: the host sends those
lanes on as one run, and a lane the move leaves alone travels on as it was
(host/motion.md, a channel lane by lane). A given motion is that move's alone:
the next write that names none lays the value's own back with its destination.

## A movement's result

Every movement ends once, and `MotionRun.result()` answers how:

```text
  .reached(.animated)                     it traveled there
  .reached(.immediate(reason))            put there at once: there already, a
                                          motion that does not animate, less
                                          motion asked for
  .superseded                             a newer destination, a snap, the
                                          user's hand
  .stopped                                `stop()`
  .detached                               the last consumer left
  .notStarted(.noReceiver)                written; nothing shows the state
  .notStarted(.invalidDestination)        the state refuses it; nothing written
  .notStarted(.unsupportedValue)          written; the host carries the state as
                                          the value itself
  .notStarted(.noAnimator)                written and shown at once; an engine's
                                          state with no engine registered
  .notStarted(.incompatibleAnimator)      an engine's state takes no motion
  .notStarted(.inactiveOwner)             the handler asking was superseded
  .notStarted(.readOnlyDerived)           a derived state with no way back
```

The host says how a run ended as a `HostMotionOutcome` through
`HostBoundary.complete(_:as:)`, after it applied the run's last frame; the
core answers `.detached` itself as a channel closes, and every `.notStarted`
before anything is booked. `.reached` is the boundary's word that the last
sample was applied, not a frame seen on the glass.

Each waiter waits under a number of its own. A task cancelled while it waits
stops waiting with `CancellationError` and leaves alone: the movement goes on
for every other waiter, and `stop()` is what ends it. Every resume is counted
as it is made and taken back as the waiter runs again
(`Renderer.resumesPending`), so a host waiting for the queue to go quiet never
waits on one already answered. A waiter the application's end takes hears
`.detached`.

## Stopping

`stop()` raises the stop counter, leaving the value where the animation stood;
the host ends the run, makes that its destination and answers the waiter
`.stopped`. The color pair the state kept is let go: the value stands at a
color between two, which no pair names. A state with no channel is unaffected.

## Writing the parts

Each write lays the lanes of its own parts and leaves every other lane as it
lies, bit for bit. A value read back through its type is not always the lanes
it came from - a color is eight bits a channel, and the host reports the
frames between them - so a stop or a move laying the whole journey again would
say the value and its speed moved, and the host would start over from them
(`JourneyTests.testAJourneyWriteLaysOnlyItsPart`).

Only a write of the destination is a write of the state: it alone moves the
image's stamp, which an engine following the state compares, and the
destination's revision, which a conversion compares.

## An engine that animates

A state declared `@State(animatedBy: .engine)` is animated by the one engine
registered for it with `engine(animating:)`. The state keeps an
`AnimatorSeat`: who the animator is, the call under way, and the movements
handed to it.

```text
  one animator         a second `engine(animating:)` is refused, naming both
                       places, and stands inert
  a token a call       `EngineMotion` is good for the call it is handed to;
                       kept, it writes nothing
  update               lays where the value stands and its speed, and offers
                       them as the frame's sample; no destination
  finish               lays the value on its destination, still, and ends the
                       movements handed over `.reached(.animated)`
  .wait                waits for the next destination; it is no arrival
  less motion          the value is landed for the engine and the author's
                       arithmetic is not run: `.reached(.immediate(.reducedMotion))`
  no animator          the destination is shown at once: `.notStarted(.noAnimator)`
```

`move(to:)` on such a state writes the destination and books the movement
with the seat. A newer destination ends it `.superseded`, a stop `.stopped`,
the animator or the last consumer leaving `.detached`. A finished movement is
answered by the host once it has shown the frame: the cycle hands the ids over
in `HostCycle.finished`.

Animators run before every other engine of a cycle, each on what the frame
before left, and the samples they offer are published together once they have
all run ([engine order](cycle.md#engine-order)): no animator reads another's
half-made frame.

## What a run reads

A motion layout's run reads two things of the journey its parameters travel
on (`Journey+Run.swift`, which nothing outside the library reaches): where
the host's channel shows them (`walked`) - the lanes' own value, under the
hand where a hand holds them - and where they are going (`going`), the
state's own. It writes neither: the hand's hold and its letting go are the
host's, said as the channel's reports
([a lane a hand holds](../host/motion.md#a-lane-a-hand-holds)).

## Readings

`.samples($fade.journey, into: $shown, .every(.milliseconds(100)))` copies the
sample's value into an ordinary state at most ten times a second; the body
reads that state under the ordinary rules. The window belongs to the reading,
not the state: one journey may be read by two views into two states at two
rates, taken in the order asked. A reading is a consumer of the channel while
its element stands.

```text
  the sample changes   due(at: frame):  now        -> take it, the window starts here
                                        waitUntil  -> book it with the board for the
                                                      window's end
                                        waiting    -> one is booked and covers this
```

Time is the display's: a reading asks the board's `frameTime`, and one booked
is taken by the first cycle at or past its time (`CycleBoard.book`), the board
awake until then, so the last frame of an animation arrives. With no sample to
deliver nothing is booked and no clock is held. Nothing here sleeps.

The window has to survive the render the reading's own write asks for. That
render walks the very view that asked for the reading; made afresh there, the
window would start over. So a standing reading at the same rate is handed the
new render's closure and kept; a changed rate is a new reading.

A reading belongs to the element that asked for it. The image and the board
know it weakly and the element (`RenderedNode.readings`) holds it: one whose
element left is never taken. A reading into its own source, or into a state
its source goes back to, is refused: it would feed itself.

## Conversions

`$volume.convert { $0 * 100 }` is a second state whose destination is worked
out from the first's destination. It is a state of its own identity: shown by a
host it has its own channel and travels under its own motion (`motion:`,
the application's unless said), whatever its sources travel under, and showing
it opens no channel for a source. It never reads where a source stands on a
frame, a source's speed or a source's motion.

What it does not promise is `result.value(t) == f(source.value(t))`. A value
that must follow the presentation frame by frame is an engine following the
journeys, or a layout's own arithmetic.

```text
  derived state   known to the first source's storage under a key spelled
                  nowhere (DerivationKey): where the element being built
                  stands - the keys from the root down to it - and the call's
                  file, line and column (PathNumber), the identities of the
                  ForEach rows it stands in, and which time that line ran in
                  the build; held by that element as it holds its readings: one
                  state per use across renders, each row of a ForEach its own,
                  a helper called twice two; an element that leaves takes its
                  own; made with no element being built, the source holds it,
                  worked out at once
  sources         each the storage its binding was made from, held, asked for
                  the one it stands for - itself, or the one it was given up for
                  at an adoption while that stands (state.md, storage and box)
```

Handing a conversion on reads nothing. A body that reads one reads its sources:
the value is brought up to the writes made so far on the read
(`Conversion.refresh`), with no render forced and no channel opened, and the
body becomes every source's reader.

The arithmetic is synchronous and has no effect. While one runs
(`ConversionEvaluation`), a state written and an act sent are refused and
said; a state read that is not a source is said, since the result will not
follow it.

No ring of references closes. The derived state is kept on the first source,
strongly where no element was being built, and its conversion's arithmetic
holds the sources; so the derived state knows its conversion weakly. What owns
a conversion is the element wearing its result and the binding made for it.

## The graph of destinations

The conversions whose results live elements wear form a graph
(`ConversionGraph`, the board's). A conversion is stale when a source's
destination revision moved since it was worked out
(`AnyStateStorage.targetRevision`: the image's count of changed destination
lanes, or every write where the value cannot be compared).

```text
  settled      before a patch is prepared, and twice in a cycle: after the
               writes are latched and after the engines ran
  order        a conversion after every one it is worked out from; the rest in
               the order declared
  one pass     each stale conversion once: an upstream result published makes
               the next stale within the pass, so two branches of one source
               meet at their common result once, both moved
  equal        a result equal to the last is nothing: no revision, no movement
               begun again
  published    a destination alone (`Storage.publish`): the result's standing
               value and speed are its channel's
```

A declaration that would close a ring - a source worked out from the very
result - is refused, said once, and the declaration before stands. No fixed
point is sought.

## A chain of conversions

A conversion of a conversion - `$volume.convert { $0 * 100 }.convert { "\(Int($0))%" }`
- is worked out from the first sources. Each conversion holds the ones its
sources are the results of (`upstream`), since the middle of a chain has no
binding of its own once the expression writing it ends; the element wearing
the last wears every link, so a write to the first source goes through the
chain in one pass. A body reading the last reads every link's sources.

## The way back

`back:` says what a derived value goes back to, in each source's own type. It
runs for a write into the result and for nothing else: the user's report on a
control, or the program's write to the derived binding. A frame of animation,
a measured frame, a result published from its sources and a patch applied
again never run it. Who made a report is said, not worked out:
`HostBoundary.report` carries a `WriteOrigin`.

`Conversion.writeBack(_:origin:)` is one transaction, whole or not at all:

```text
  gathered     a destination for every source, up the whole chain; a link with
               no way back makes the result read-only
  merged       one state met twice takes one value: equal proposals are one,
               others a conflict
  asked        each state's own refusal, as things stand; then every source
               staged silently and each asked again with all the others
               standing
  canonical    the chain worked out over the staged sources; a program's value
               must be exactly that - `forward(back(value)) == value`
  taken back   everything staged, whatever the answer
  committed    every source written together: where the user put it, at once
               and still; where the program did, a destination under its own
               motion; then the chain worked out for good
```

A refusal leaves nothing written and wakes nobody: staging restores each
state's value, what the host carries of it and what waited to be published,
and every count (`Storage.stager`). A refusal that reads the other states
anywhere but their storages reads what the same write proposes for them
(`BackProposal`): a window's value does.

After the user's report the control stands at what its sources make of it
(`Conversion.land`): the round trip's value where the way back is no exact
inverse, the value before where the report was refused or the result is
read-only. A program's write to a read-only result is refused and said, and
`move` answers `.notStarted(.readOnlyDerived)`. A `move` of a result with a way
back is the transaction first, then one movement of the result's own channel
under the motion given.

## A conversion declared again

A conversion is one object across renders, and each render declares it again:
its sources, its arithmetic, its motion and its way back are the new
declaration's alone. A body that wrote `back:` before and does not now leaves
no way back, and a report made while there was none goes back to nobody,
then or later (`Conversion.declareAgain`, `declareBack`).

## Many sources

`.multi($a, $b).convert { a, b in … }` is the same machinery over two to ten
states. `.multi` is a static member of `Binding`, so the leading dot resolves
against the type the control takes. The arities are written out one overload
each, because no parameter pack says "two or more" (measured on Swift 6.4): a
pack alone takes `.multi()` and `.multi($a)`, and a pack after two named
sources leaves its empty tail uninferred, so the commonest call does not
compile. The sources are read off their storage, not through their bindings,
so the line that wrote the conversion does not become a reader of every
source. Two states take a way back as one does, the way back answering both,
each in its own type.

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
                                    damping cases are the textbook ones; an
                                    overdamped one's rates written so no
                                    damping a motion admits overflows or
                                    cancels them away
  no number                         a sample past what a double holds - its
                                    speed told back per second included -
                                    lands, for every animator alike
  still                             0.001 in the value's units, and 1 a second
                                    for a speed: below any display's resolution
                                    for a color channel (0 to 1) or a point
  longest                           a spring is over after 10 s, so no animation
                                    holds a display clock awake for ever
```

Time is in milliseconds, the unit a `Motion` keeps its length in, and a speed
is per second everywhere - told to the law, answered by it, carried by an
animation and reported by a sample - the law alone working in milliseconds
inside, so no animator converts. The slope of an eased curve is a central
difference on the curve, a function of progress alone, so it answers the same
number in every run.
