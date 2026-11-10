# Patches in the runtime

How a runtime takes the core's patches: whole, against the tree they were
computed from, with every native write the program's. [The runtime](runtime.md)
draws where the intake sits in a turn.

## Patch intake

A patch means something only against the exact tree it was computed from. The
intake quotes the generation of the last message applied in full, applies the
next as one transaction - every native write the program's, every handler it
raises queued until the message is in - and claims the message's generation
only when it went in without drift. A drift is a sparse message about a tree
the host does not hold: a child the element does not have, a child of another
type sent without `replace`, or a root that is not the mounted one. A drifted
message is refused and the whole tree is asked for once, with
`render(baseline: 0)`, which keeps every key, handler and state. A message
applied inside another is computed against a tree half written, so the outer
one claims nothing and the next render is complete.

## A complete message

A complete message - the first, and every one after a drift - says everything
of each element it carries. The core says it against the host's own defaults,
as to a host holding nothing: a property, a handler, a tie to a state or a
motion at its default goes unsaid, and `clearedProperties` names only what
the core's own last render had. A host that keeps an element may hold more -
whatever a message that never went in whole left on it. So an element a
complete message keeps holds only what the message names: a property, a
handler or a tie it does not name goes, and a motion it does not say is the
inherited one (`MountedElement.completed`). What it names as the element
holds it already is no change: its native half hears changed only a value or
a tie the message names otherwise, as a control writing what it is told anew
- a web view loading its source again, a field its words - would undo what
the user did with it. A sparse message leaves what it does not name as it
stands. The mounted tree knows which a message is from
`apply(_:complete:)`; a test host applying patches of its own says a message
is complete only where it describes another root than the one standing
(`holdsRoot(of:)`).

## Program write

While the program writes a native control - a patch applied, a display frame
presented, or the host moving a control itself - the control's own callbacks
are the write's echo and report nothing, so an application's write never returns as a user event. One mark
says so, `ProgramWrite`; no control keeps a flag of its own. The intake marks
each patch it applies and the tree each frame's walk, so a host marks only
the writes it makes of its own accord. A callback the
platform delivers after the write has returned is outside the mark, so a
control that raises one - a pop-up menu the program opens - marks it where it
opens.

## What a message costs

While an inspector records, the runtime tells it its half of every message,
on the pass of the message's generation: how long applying it took, the
elements it walked, how many it mounted anew and how many it found standing -
the rest - and how long each scene's part took, by the scene's place in the application's list. The
mounted tree keeps that tally, `RenderTally`, for the message the intake is
applying, and tells it through the core link once the message is in. A typed
patch is read off no buffer, so its read time is nothing. While no inspector
records and `STATEUI_TALLY` is off there is no tally: each count is one test
of a nil, and no clock is read.

## What a runtime writes out

Two switches in the process's environment make a runtime write text for
whoever reads its log rather than its screen, on the standard error - which an
Android runtime sends to logcat. `STATEUI_TALLY=1` writes the running totals:
the messages applied, the elements they walked, made and kept, the core's
renders, empty renders, refused writes, live elements and runs under way or waiting
(the core's tally),
the host's own views alive (`views`, which `HostRuntime` takes - a view
outliving its element shows there while the elements' count comes back), the
host layer's elements alive (`elements` - one a host holds after the tree
dropped it shows there while the core's `alive` comes back), and the apply's
average, worst and total time. The totals run from the start,
so a run is read as the difference between two lines. A line is written after
a message that stands alone - a third of a second after the one before it,
which is what one action earns - and at most every tenth of a second in a
burst, since writing after every message moves the timing it measures.
`STATEUI_INSPECT=1` starts the inspector's recording with the tree and writes
every pass once the host has reported on it, the way the inspector shows it.
`DiagnosticText` reads both switches, keeps the totals and writes; the tree
hands it each message's tally.
