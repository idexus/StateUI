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

## Program write

While the program writes a native control - a patch applied, or the host moving
a control itself - the control's own callbacks are the write's echo and report
nothing, so an application's write never returns as a user event. One mark
says so, `ProgramWrite`; no control keeps a flag of its own. A callback the
platform delivers after the write has returned is outside the mark, so a
control that raises one - a pop-up menu the program opens - marks it where it
opens.

## What a message costs

While an inspector records, the runtime tells it its half of every message,
on the pass of the message's generation: how long applying it took, the
elements it walked, how many it mounted anew, how many kept rows took another
row's description, and how many it found standing - the rest - and how long
each scene's part took, by the scene's place in the application's list. The
mounted tree keeps that tally, `RenderTally`, for the message the intake is
applying, and tells it through the core link once the message is in. A typed
patch is read off no buffer, so its read time is nothing. While no inspector
records there is no tally: each count is one test of a nil, and no clock is
read.
