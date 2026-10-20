# Benchmarks

Four gestures run over the core and the host layer on a clock wound by hand,
and what each costs is counted: a held icon moved across a home screen of 48,
a thousand rows scrolled to their end, a run of cards thrown, and two hundred
rows put in a new order. They stand in the host layer's package as the test
target `StateUIHostBenchmarks`.

The counts are the gate. Every run of the host layer's suite - debug on
macOS, Linux and Windows - asserts each gesture's counts exactly, so work that
comes back fails the run, and work that goes is written down in the same
change, the new counts beside the reason. A count is the same on every
machine and every build: the clock is the bench's, the hand's steps are the
test's, and nothing waits on a toolkit.

The times are a trend. Each gesture writes one line - its steps, their
median and longest time, and its counts:

```text
StateUI benchmark home screen, a held icon moved a cell (release): 12 steps, median 1.419 ms, ...
```

A shared runner's clock is too noisy to fail a run on, so the line is read
across runs, never asserted; it says whether it came from a debug or a
release build, and only a release build's is a measure:

```bash
swift test -c release --package-path lib/StateUI/StateUI.Host --filter StateUIHostBenchmarks
```

CI runs that once on macOS, beside the suites.

## What is counted

```text
  renders    the core's renders                         HostTally
  built      composed views' bodies built
  walks      views walked for their state and inputs
  texts      identities named with a text
  made       native halves made                         the bench's
  applied    patches applied to a native half           native halves
  arranged   children arranged again by a frame
  presented  frames presented to a native half
  placed     children a run placed
  left       native halves let go as their element left
```

The first four are the core's, kept for the tally (core/diagnostics.md). The
rest are the calls the host layer makes on a native half - each a toolkit's
call on a native host, a relay's on the Web and Android - so they count what
a host pays for, whatever its toolkit.

## A native half with no toolkit

The bench's native half (`CountedView`) does with the host layer what every
host's does, and nothing more: it places a run's children in drawing order
by the shared arithmetic, keeps an ItemsView's cells (`ItemsCells`), and says
where it stands, in the bench's room, wherever the tree reads it. Its runtime
has a presenter that shows no window: a runtime without one presents no
frame.

## The gestures

- **A held icon moved across a home screen.** A layout engine of 48 icons,
  twenty a board; a press held 600 ms takes an icon, and twelve moves take it
  a cell on each time, 100 ms of frames apart. A new order builds the board
  again and no icon.
- **A thousand rows scrolled to their end.** An ItemsView of a thousand rows
  and a screen of sixteen cells, reused as a platform's collection reuses
  them: two rows on a frame, each cell leaving the top taking the next row
  below. Rows are built in batches as the cells near the end of what was
  built, and let go behind them.
- **A run of cards thrown.** A gallery of twelve cards, five quick moves and
  a lift at 2400 points a second; thirty frames are measured. The throw
  rebuilds no card: the one render is the middle card changing.
- **Two hundred rows in a new order.** A stack of two hundred composed rows,
  the first put last twenty times. The page is built again and no row; no
  view is made or let go.

## The leak walk

The Gallery's own suite walks every sample over the core and the host layer
(`LeakWalkTests`): it chooses each group from the menu and, on the group's
page, opens each sample by a tap on its row, gives it a second of frames, and
goes back the way the window offers. What stands alive after the way back is
what stood on the group's page before the visit:

```text
  elements   the core's rendered elements alive     HostTally.alive
  runs       runs under way or waiting               HostTally.runs
  halves     native halves made and not let go       the walk's
  channels   the host layer's state channels         StateChannels
```

Its presenter shows the windows by the host layer's own presentation, so a
page hears its phases as on a host, and answers every act as a host answers
what it cannot perform - with a failure - since a run awaiting an act no one
answers stays under way. A tap that opened no page fails the walk too, so a
count cannot match by visiting nothing. A host's own suite proves its toolkit
lets go of every view; the walk proves the gallery's pages, states and runs.
