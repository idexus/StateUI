# The dictionary and the matrix

`docs/controls/` holds one page per element contract and per tier, and
`docs/platform-contract.md` is the implementation matrix. Wherever a
contract can say it, both are rendered from the contracts and the hosts'
declarations, so the handbook cannot drift from the code.

## Rendered from the contracts

```text
  an element contract
      first paragraph of its doc  ------------->  the opening of its page
      layer  ---------------------------------->  the "Layer:" line; the meaning comes
                                                  from ElementLayer's case docs
      tiers, as worn  ------------------------->  "Inherits:", and a table per tier
      members  -------------------------------->  a row each: name, kind, value, layer,
                                                  a mark per host, notes
      the element's verdict and its members' ->  the hosts table under the legend: a row
                                                  per host - made, members met, what it is
                                                  there, why a mark is empty
  a tier contract
      first paragraph  ------------------------>  the tier's page
      first sentence  ------------------------->  the tier list, and the line over the
                                                  tier's table on every element page
  each host's written declaration + its export  ->  the marks and their notes
  the matrix's native mapping  ---------------->  the hosts table's "Realization" column
  the views' on... modifiers  ----------------->  the modifier an event is heard through
```

The matrix's blocks - the dictionary's two tables, element creation, the
members, the shared members, the acts and the vocabulary - are rendered the
same way, between marker comments in `docs/platform-contract.md`.

## The first paragraph

The dictionary reads the `///` lines directly above `public enum
...Contract:` and takes their first paragraph as one line. That paragraph
opens the element's page, and a tier's first sentence stands alone in the
tier list and above the tier's table on every element page that wears it.
So a contract's first paragraph says what the element is, in plain words, to
someone reading the dictionary: no example, no reference, and a first
sentence that stands on its own. Detail and examples belong to the view's
own documentation.

## Marks

A mark is a test's verdict. A host's column shows only what its own suite's
run of the conformance families said of each member on each element: the
run writes one verdict a line under `exports/marks/<host>/<Family>.txt`,
and the dictionary reads those files and nothing else. A host none of whose
runs wrote a verdict has an empty column, whatever it implements.

A run judges a member by the host's register - `HostRegister`, the records
a host writes by hand and what its runtime registers - and by the case:

```text
  Button.clicked: ✅               a passing case proved it
  DatePicker.format: ☑️ <missing>  proved, while the register says what is missing
  Map: – <why>                     the host's family never has it
  Line.x1: not realized            empty: the host has no realization yet
  TextField.submitted: cannot ...  empty: the driver cannot do or read it, and why
  SplitView: waits on <member>     empty: realized, its case stopped by a member
                                   the host does not realize yet
  Switch.toggled: ❌ <failure>      a case proving it failed, its first failure
  Label.lineBreak: ◐ <why>         one case proved it, another could not run or read
```

A case runs only where the host realizes every member it covers; a member
the register calls never is marked – without the case running. The element
itself has a verdict of its own, `Button: ✅`: the creation table's mark, and
the "Created" cell of the hosts table that opens the element's page, above
its own members and then its tiers'. Every view has one case that proves it
alone, `standsAloneOnAPage` - made with nothing written on it, alone on a
page, laid out in the window at a size - and an arrangement of pages one
that shows its first page; a case that proves the element together with a
member proves it too, and the weightiest verdict stands. So a member the
host does not realize, or its driver cannot read, never hides that the host
makes the element. A tier's member and an act are marked only on the page
of each element that has it: one element may realize what another does not,
so the platform contract names them with no mark rather than one that says
both.

A tier's record reaches every element wearing the tier, and what the
host's shared machinery realizes becomes one: it serves each view the host
makes. Where an element wearing the tier does not take such a member - a
toolbar item AppKit holds as no view - the element's own record says so,
`.unrealized("ToolbarItem", "accessibilityIdentifier", why:)`, and stands
over the tier's: the member's case does not run there and its cell stays
empty. An element's record is the only one that says unrealized.

A host checks its own register in its suite (`HostRegister.problems`): a
record naming what its owner does not declare, one written twice, a partial
one saying nothing is missing, a never or an unrealized one saying no
reason, an unrealized one on a tier.

```text
  ✅   proven by every test of it that ran on that host
  ☑️   proven, but the host records what is missing
  –    never on that host's family; its register or an absence case says why
  ❌   a test of it failed; ◐ some tests proved it, another could not
  ·    the driver cannot yet do or read what its test needs; ⏸ its test waits
  ⌛   said by a run of other sources than these (Fresh verdicts)
       (empty) not realized, or no run - the note says which
```

## Fresh verdicts

A verdict is true of the sources it ran on. Each host's run writes, over each
verdict file it writes, the digest of the sources its verdicts rest on: the git
tree of the folders `.scripts/Marks/inputs.txt` names for every host and for
this one - the core, the host layer, the conformance families, the host with
its relay, its driver and the support its suite drives with - as they stood in
the working tree before the build. The host's test script works it out
(`.scripts/Marks/inputs.sh`, `Get-StateUIMarkInputs` on Windows) and hands it
to the run in `STATEUI_MARKS_INPUTS`; Android's script writes it over the files
it pulls from the device. The renderer works the digest out again the same way
(`MarkInputs`), and a verdict whose file names another digest, or none, is
shown ⌛ with no note: what it said is no verdict of these sources, and a note
repeating it on every stale cell of every host only hides the notes that
count. A run of the current sources makes it fresh again; nothing a person
remembers does.

A case's outcome is the verdict of what it proves, never of what it only
needs: `needs:` holds the button whose click makes the change, and the case
runs only where the host realizes it too. The verdicts of one subject from all
its cases combine into the worst: a failure over everything, a proof beside a
case that could not run or read into ◐, a proof whole only where every case
proved it. A case that proves its members absent on a host - a
view that refuses the keyboard and hears nothing never takes the focus there
- ends with `absent`, and they are – there with why. A case needing what the
platform holds nothing of - a value no control of it keeps, which the driver
lists in `platformHasNone` or its read throws with `because:` - does not
apply there: the member's other cases judge it, and only a member no other
case judges stays empty with why.

## Rendering again

`STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests` writes the
pages and the matrix's blocks again. Without the variable, the suite refuses
a document that differs from what the contracts render, a line that is no
verdict, and a verdict on what no contract of its element declares. A change
to a contract's first paragraph, a member or a layer is committed together
with the pages it renders; a host's verdicts are written again through that
host's own suite, with `STATEUI_UPDATE_EXPORTS=1`, and the pages after them.
