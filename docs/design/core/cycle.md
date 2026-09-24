# The cycle

Reactive path 2 runs without a render. A carried state lives on an image of
plain bytes that both sides rewrite; once per display frame the host runs a
cycle in the core, the application's engines work over one snapshot, and what
moved crosses back as typed values each way. No build, no diff, no message:
this is why a value nobody could afford to render on can be followed frame by
frame.

```text
  host frame (now, ms)
    |
    |  StateUIHost.report                          the user's changes, by lane
    v
  CycleBoard.cycle(now:)
    1 READ      every write waiting since the last cycle is latched into the image
    2 WORK OUT  the engines with a reason run, in order, over that one picture
    3 WRITE     the image is published; what moved is marked dirty
    |
    |  HostCycle.changes                           ascending state numbers
    v
  host writes the moved values onto its controls
```

## The board

A `CycleBoard` holds one cycle: the images of its states (weakly - a state
belongs to its view), its engines in running order, and one hold over both.
There is one board per sync - one clock, one cycle - and the display's own frame
is the only sync; a second would be a board beside it, driven from a thread of
the host's own.

Every touch of an image goes through the board's hold, so a handler's write,
the host's report and an engine's arithmetic cannot tear one another. The hold
is never held while an engine runs: an engine reads and writes states, and a
lock held across the call would be a lock the engine asks for again.

## Three copies of a value

```text
  image       what the cycle running now works on
  published   the last completed cycle's - what everything outside a cycle reads
  pending     a write made while no cycle runs, waiting to be latched
```

A read inside a cycle answers the image, so every engine in one cycle sees one
picture. A read outside answers the newest thing this side knows - a pending
write, or else the published copy - so a handler that writes a value and reads
it back gets what it wrote, while the next cycle still runs over a picture that
cannot change under it. Nothing outside ever sees a half-finished picture, and
running the same cycle twice over the same image answers the same bytes.

A state the host does not carry is read live, under its own lock. On the one
thread that runs handlers and engines alike that is the same picture, and it is
what makes following any state cost nothing extra.

## Where a write lands

A write inside a cycle goes into the image and marks its changed lanes dirty. A
write outside one goes into the pending slot, and wakes the host after it has
landed, outside the hold: a write from the pool - a `Task.detached`, an
`async let` child sending a movement - has no event, render or act after it to
start a cycle, and nothing else would tell the host it is there.

Each write bumps the value's stamp, even where the bytes are what they already
were: an engine following a value a finger is holding still is entitled to hear
every report. `forcing` marks lanes dirty that a write means even where the bytes
did not move, such as a fresh destination and waiter (journeys.md).

Lanes are compared bit for bit, not by number: a value carries what a platform
reported and what arithmetic worked out, where `-0.0` is not `0.0` and a NaN is
itself, and this comparison decides whether anything crosses. Dirty bit n is
lane n; bit 63 means "lane 63 and every lane past it".

## What the host reports

A host's write names the lanes it wrote. Those lanes are laid into the image
and their dirty bits cleared: a lane the host wrote is one the host already has,
and reading it back out would tell the platform what it just said, every frame.

A report speaks about lanes and never about shape. The shape is the value's
declaration's, so only the named lanes both sides have are laid; a shorter or
longer report leaves the rest of the image standing. Replacing the image would
throw away every lane the report says nothing about - a journey's law, its
waiter, its stop count - and every later write would cross as a whole new
value, which the host reads as a jump. A report naming every lane may change
the value's length, as a text does.

A Swift host reports a journey by its parts (`HostJourneyUpdate`): a frame is
value and velocity; aiming, stopping and landing add the destination.

## The per-frame read

What crosses to the host is what a cycle finished, never the image a cycle is
working on. The per-frame read answers every state with dirty lanes, in
ascending state number - the order is what makes two runs of one cycle write
the same bytes - and clears the bits it answers. A read of one state whole
clears nothing: a registration needs the value and where it is going both.
Every read goes through `HostStorage.crossing()`, which resolves an inherited
law (journeys.md).

A read into a buffer too small clears nothing, so it can be made again with
room.

## A start is a gap

The first cycle, and any cycle after a silence longer than
`EngineCycle.mostElapsed` (100 ms), only latches. An application that was
asleep has a pile of reports and no elapsed time anybody can act on, and an
engine handed a gap of minutes would move whatever it moves through the wall.
The start moves every engine's clock to now, so the next run is told about one
frame; it does not note where the values stand, because a write made while
nothing was cycling is a reason to run.

## Engines

An engine is the application's arithmetic run on the host's frames, written
with `.engine(following:)`: the only place in the library where code runs
outside a render. What it may do is narrow on purpose - read states, write
states, and say whether it has more to do. It may not await, ask the host for
anything or touch a control, because it runs inside the frame the platform is
drawing. The closure captures the view by value, so everything it reads that
can move is a state and everything else is a copy of what the render saw;
anything it must remember between cycles lives in a `@State`.

```text
  EngineCycle    the instant, and how long since THIS engine ran (at most 100 ms)
  EngineAnswer   .again - run next cycle, whatever is written; holds the clock
                 .wait  - nothing more until a followed state is written
```

The answer is about work, not movement: an engine counting how long a room has
held still has more to do and moves nothing. Nothing bounds how long an engine
answers `.again`, and one that keeps the display awake for a picture that is not
changing spends battery on nothing.

## What wakes an engine

A write to a state named in `following:` is the only reason to run, whoever
made it: a handler, a control reporting, the host's frames, another engine. A
state read inside the run and named nowhere wakes nothing - the engine runs
outside every render, so such a read is recorded nowhere, and writing that
state rebuilds nothing and arms nothing. A value the arithmetic needs is
followed, or read in the body and handed over as a local.

An engine's own write to a state it follows is no reason either: where
everything it follows stands is noted after the run (`noticed()`), so what it
changed itself is what it has already seen. A render that describes the view
again arms the engine once with the new closure (`rearm`).

```text
  stamp      every write counts, this side's and the host's, equal bytes included
  seen       each followed state's stamp as the engine last ran
  stirred    any followed stamp differs from what was seen -> run
  armed      a render described the view since the last run -> run
  awake      the last answer was .again -> run
```

A state's stamp is its storage's own write count plus its image's, because a
value has two homes in its life. The storage's count is an atomic read without
the storage's lock, on purpose: `carry()` takes the board's hold while holding
the storage's lock, and `stirred()` reads stamps under the board's hold, so
taking the storage's lock there would take the two in the other order. A write
from a detached task is seen a cycle late at worst.

A render that names different states to follow forgets the stamps, so the next
cycle runs over the new list; one naming the same states leaves them, or every
render would be a reason to run.

## Engine order

Engines run in ascending priority, ties in the order they were first
registered, so one that reads what another wrote in the same cycle says a
higher number. A conversion's engines run first (journeys.md). Each engine of
an element is paired with its predecessor by the order the modifiers appear
in, so an `.engine` under an `if` changes the count, and every engine of that
element starts over (identity-and-diffing.md).

`.engine(following:)` has two forms because Swift resolves one of each and not
two of a kind: it cannot rank two parameter-pack overloads against each other
for a multi-statement closure, nor two existential ones for a closure over two
states. The form answering nothing takes `any Followable`; the form answering
an `EngineAnswer` takes a pack. `Followable` exists for the first.

## State numbers

The host quotes a carried state by a number. It is issued the first time
anything asks - the differ asks as it registers a driven property - and kept on
the image, so it survives every rebuild. Properties are walked in name order,
so numbers follow the walk and two runs of one tree number alike, which is what
makes a fixture's bytes a contract. Zero is never issued: `cycleRead(0)` means
every state. The renderer's table of numbers holds each image weakly; a number
whose state has gone answers nothing.

The tests share one renderer across a whole run, so they put the numbering back
to a fresh process's before each fixture; nothing a running interface could
survive, since a value whose number is forgotten while the host still quotes it
would be told about somebody else's movement.

## The image

A value lies on the image as little-endian bit patterns, eight bytes a lane, or
as a text's own length and UTF-8 (`StateImage`), written by hand because the
library imports no Foundation.

## The ticker

`Ticker` is a repeating timer built on `Task.sleep`. Nothing turns a run loop on
Android or Windows, so no timer here hangs off one; `MainActor`'s jobs reach the
UI thread everywhere, and a resume wakes the host (concurrency.md). It is not
named `Timer`, which would clash with the type of that name in an application
that imports Foundation.

```text
  sleep to a deadline        not for a length: each resume is a few ms late,
                             and sleeping for the interval adds every one up
  one run token              start() retires the previous loop, so returning to
                             a page never leaves two loops counting
  a tick asks for a render   naming the ticker, so a view reading `ticks`
                             follows with nothing subscribed
  one lock                   the count, the running flag and the run change
                             together; reads go through it, renders are asked
                             outside it
  the last tick stops first  before its closure runs, so the closure can start
                             the next round - start() on a running ticker does
                             nothing, and a stop written after would undo it
```

Its values are not separate `@State`s because they change together: a tick
moves the count, the last one clears the running flag, and `start`, `stop` and
`reset` arrive from wherever the tick's work ended up; read from separate locks,
`start()` racing a last tick could see the count of one moment and the flag of
another.

A lap that took longer than a whole interval would leave the deadline so far
behind that the missed laps all come due at once, so the next deadline is
measured from now. The test is a whole interval, not merely "the deadline has
passed": a sleep overshoots by the platform's floor, and clamping on that hands
the overshoot to the next lap, one lateness per tick. The interval's floor is a
millisecond: zero or less would never reach ahead of the clock, and the loop
would tick as fast as the UI thread could carry it.
