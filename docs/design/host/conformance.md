# Conformance

How one suite proves that every host does the same work when it executes the
contract. A host looks as its platform's applications do - its tabs, menus
and controls are its toolkit's own - so what the suite asserts is never a
look: it is what executing the contract DOES.

```text
  core tests                 state, diffing, patches, contracts - pure Swift
  host layer tests           the arithmetic and the runtime every host shares - pure
  conformance                the contract's effects, on each real toolkit
  a host's own tests         its look, the native API behind a member, its traps
  the Gallery                real input from outside, walked on each platform
```

## What a case asserts

A case asserts effects of executing the contract: a state written, a handler
heard once or not at all, which choice, tab or page is selected or shown, a
value kept inside its range, words cut to their bound, what holds the focus,
what a press reaches, what is let go. Never a pixel, a colour, a font, a
native widget's kind or an exact place: those belong to the host's own tests,
beside the native API they prove.

## A case

A case is written once, in `lib/StateUI.HostConformance`, as a page, what the
user and the program do to it, and what must follow. It says which members
of the contract it covers; it runs on a host only where the host realizes all
of them, by the rule the control dictionary reads (`HostMarks`), so a case can
never pass on a host that does not claim the member. A case covering a member
the host's family does not plan says so and does not run; one covering a
member the host lacks names the gap, which its column already shows. A case
never asks which host it runs on.

Cases stand in families - toggles, values, fields, choices - and a host's
suite runs each family as one test, so a case added to a family runs on every
host with no edit there.

## The driver

Each host's test target supplies a driver: how its toolkit starts a page,
turns, steps and draws a frame, what a user's act is through its toolkit's
own input path, and what a native control holds of a member, as the contract
writes the value. A driver reads through the element a case found by its
`.id()`, and names no widget to the case. What a driver cannot read or do
throws; where the driver says why it cannot, the case says so and does not
fail, and otherwise it fails - a nil never stands for "unknown".

## A session

A case reaches its host only through its session: the page it starts, the
elements it finds, the acts it performs, the values it reads, and its
expectations. A session waits for an effect by stepping the host until it
holds, at most 150 steps, and sees that nothing happens by one turn of the
pump alone. Motion is driven by a test clock and display frames, never by
the time a machine takes.

## The runner

The runner runs a family on a host and says one line for each case - passed,
failed, not planned, a gap, or what the driver cannot do and why. Nothing is
passed over in silence: a case covering no member fails, and so does a
family none of whose cases ran. A failure names the host and the case, at the
line of the case's expectation.

## What a run proves

A case that passes proves every member it covers on its host: the runner
returns them, and each host's suite holds a family's proofs to
`exports/covered/<host>/<Family>.txt` - one "Element.member" a line - or
writes them there on a run with `STATEUI_UPDATE_EXPORTS=1`, read in the diff
as an export is. Those files are every ✅ a host's column shows: nothing a
host implements is marked until its own test proves it. A test of a host's
look proves a member the same way, as a case of a family its own suite
holds.

