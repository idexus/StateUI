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

A case is written once, in `lib/StateUI/Tests/HostConformance`, as a page,
what the user and the program do to it, and what must follow. It says which
members of the contract it covers; it runs on a host only where the host
realizes all of them, by the host's register (`HostRegister`), so a case can
never pass on a host that does not claim the member. A case covering a member
the host's family does not plan says so and does not run; one covering a
member the host lacks names the gap. A case never asks which host it runs on.

## One family per contract

Cases stand in families, one for each contract the library declares, as the
control dictionary has one page for each: `Contract/Controls/ButtonTests.swift`
for an element wearing View, `Contract/Structure/` for the parts of an
application's structure, `Contract/Tiers/` for the tiers. A member's events
and acts stand in the family of the contract declaring them. `Families.all`
lists them, and a host's suite runs each family as one test, so a case added
to a family runs on every host with no edit there.

Every cell of the dictionary has a case of its own contract's family: the
element itself - the host makes it - each of its own members, and each
tier's member on every element wearing the tier. `ContractCompletenessTests`
holds the families to that, so a host's run gives a verdict on every cell.

## A member's aspects

A member is covered by what it does, not by one sighting of it. A property's
floor is `Aspects.holds`: the value the tree gives reaches the native
control, and so does the value the tree changes it to. An event is heard
once for the user's act and not at all for the program's; an act answers,
and refuses or cancels as the contract says. Where a property has an effect
a case can see without reading the control - a frame, a colour StateUI draws,
what a press reaches - a case of the effect stands beside it. A property no
toolkit holds - a radio button's set, which StateUI keeps - has its effect
alone; where one host's toolkit holds a property another leaves to StateUI's
arithmetic - a stack's spacing - the second's driver says why it cannot read
it, and the effect proves it there.

## A tier's cases

A tier's member - a view's opacity, its being shown - is the contract's on
every element wearing the tier, and each element's ✅ is proven apart. A
tier's case is written once and made for each element: every element the
library declares has a specimen, the smallest of its kind standing where an
application puts one - a control in a stack, a span in a label's words, a
menu's item in a view's menu, a toolbar's on its page's bar, an arrangement
as the page, a title bar over its window - which the case dresses with the
members it writes, through the element's own `setValue`, and finds by its id
or as the one element of its kind. The case runs on a host for each element
the host realizes, and proves the member there.

## The driver

Each host's test target supplies a driver: how its toolkit starts a page,
turns, steps and draws a frame, what a user's act is through its toolkit's
own input path, and what a native control holds of a member, as the contract
writes the value. A driver reads through the element a case found by its
`.id()`, and names no widget to the case. What a driver cannot read or do
throws; where the driver says why it cannot, the case says so and does not
fail, and otherwise it fails - a nil never stands for "unknown". Besides a
member's value a driver reads a view's menu, whether it holds the keyboard,
what a press at a point reaches, the question the window shows, what the
screen reader was told, the colour StateUI draws at a point - never a native
control's look - the host's log and what it keeps; each read a host does not
have yet is its driver's "cannot".

## A session

A case reaches its host only through its session: the page it starts, the
elements it finds, the acts it performs, the values it reads, and its
expectations. A session waits for an effect by stepping the host until it
holds, at most 150 steps, and sees that nothing happens by one turn of the
pump alone. Motion is driven by a test clock and display frames, never by
the time a machine takes.

## The runner

The runner runs a family on a host and says one line for each case - passed,
failed, not planned, a gap, or what the driver cannot do and why - and gives
the verdict on every member the cases cover. Nothing is passed over in
silence: a case covering no member fails, and a family none of whose cases
ran - an element the host realizes none of - says why for each, and its
verdicts say it too. A failure names the host and the case, at the line of
the case's expectation. A host may run a large family in parts
(`Conformance.Part`), each every n-th case, the parts together every case
once, each writing its own file of verdicts; the dictionary reads them all.

## What a run proves

A run gives a verdict on every member its cases cover, one line each under
`exports/marks/<host>/<Family>.txt`, written with `STATEUI_UPDATE_EXPORTS=1`
and held to the file otherwise: ✅ where a passing case proved it, ☑️ with
what the host's register says is missing, – with why where the host's family
never has it, and - empty in the dictionary - "not realized" or what the
driver cannot do and why. A member of a failing case gets no verdict from it.
Those files are every mark a host's column shows: nothing a host implements
or declares by hand is marked until its own run says so. A test of a host's
look proves no member; it proves how the host draws.
