# The dictionary and the matrix

`docs/controls/` holds one page per element contract and per tier, and
`docs/platform-contract.md` is the implementation matrix. Wherever a
contract can say it, both are rendered from the contracts and the verdicts
the hosts' test runs write, so the handbook cannot drift from the code.

## Rendered from the contracts

```text
  an element contract
      first paragraph of its doc  ------------->  the opening of its page
      its example  ---------------------------->  a Swift block under that paragraph
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
      its example  ---------------------------->  a Swift block under that paragraph
      first sentence  ------------------------->  the tier list, and the line over the
                                                  tier's table on every element page
  each host's verdict files (exports/marks)  --->  the marks and their notes
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
sentence that stands on its own. Detail belongs to the view's own
documentation, and the page's example to the dictionary (Examples).

## Examples

Every page shows its contract in use right under its first paragraph: a
short Swift block, before the hosts and the members. An element's example
declares it as an application does - a control with its purpose value and a
modifier or two, a structure part through the modifier or the arrangement
that declares it (`.toolbar { }`, `.overlays { }`, `ModalStack`); a tier's
example writes its members on one of the elements wearing it.

The examples are written once, in the dictionary's own source,
`ControlDictionaryExamples.swift` beside `ControlDictionary.swift` in the
core's tests: one entry per contract, keyed by the contract type, so an
example of a contract that is gone does not compile.
`ControlDictionaryTests` refuses a contract with no example or with two, and
an example of a contract with no page. The renderer copies each into its
page, and the Gallery's `DocumentationExamplesTests` compiles each block of
the pages as it compiles every block of the handbook - against the public
module, `import StateUI`, as an application is compiled. The core's own
tests import the library `@testable`, where an internal member compiles
too, so the examples are held as text there and proved where the handbook
is.

An example is self-contained: it declares the state it reads, as a
function body - `@State var count = 0` beside the control - or as the types
of a small application where its contract is one (`Application`, `Scene`,
`Window`, an arrangement).

A provider's element a host may not realize - a `Map` - shows under its
example what an application registers with such a host
(`ControlDictionary.registrations`): a sentence, and the
registration quoted - `swift quote`, never compiled, since it is written
against a host's facade and the handbook compiles against `StateUI` alone.

## Marks

A mark is a test's verdict. A host's column shows only what its own suite's
run of the conformance families said of each member on each element: the
run writes one verdict a line under `lib/StateUI/exports/marks/<host>/<Family>.txt`,
and the dictionary reads those files and nothing else. A host none of whose
runs wrote a verdict has an empty column, whatever it implements.

A run judges a member by the host's register - `HostRegister`, the records
a host writes by hand and what its runtime registers - and by the case:

```text
  Button.clicked: ✅               a passing case proved it
  DatePicker.format: ☑️ <missing>  proved, while the register says what is missing
  Map: – <why>                     the host's family never has it
  Marker.label: 🧩                    the host leaves it to the application, which
                                   registers its own control for it
  Line.x1: not realized            empty: the host has no realization yet
  TextField.submitted: cannot ...  empty: the driver cannot do or read it, and why
  Text.isEnabled: does not apply - ...
                                   empty: the host's platform holds nothing the case
                                   reads, and why - beside any other case's word,
                                   that word stands
  SplitView: waits on <member>     empty: realized, its case stopped by a member
                                   the host does not realize yet
  Switch.toggled: ❌ <failure>      a case proving it failed, its first failure
  Text.lineBreak: ◐ <why>         one case proved it, another could not run or read
```

A family split into parts writes a file a part, and the dictionary takes the
worst word each subject has across them; a case that does not apply on the
host gives way there to any other case, so a member another part proves
stands proven.

A case runs only where the host realizes every member it covers; a member
the register calls never is marked – without the case running, and one of an
element the register leaves to the application (`byApplication`) - a map on
a platform with none of its own - is marked 🧩 so. A – counts as met: the
host has done all it will, and the contract is kept there by the family's
nature. A member proven only through the host's own entry or record, ✓,
counts as met too - it works and its effect is proven, by weaker evidence.
A 🧩 is shown and not counted: what the user gets there is the
application's. Every total gives each mark counted as met a row of its own,
and 🧩 one, so the evidence stays in sight beside the sum. The element
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
  ✓    proven only through the host's own entry or read, which the driver names
  ☑️   proven, but the host records what is missing
  –    never on that host's family; its register or an absence case says why
  🧩   left to the application's own registration on that host
  ❌   a test of it failed; ◐ some tests proved it, another could not
  ·    the driver cannot yet do or read what its test needs; ⏸ its test waits
  ⌛   said at another revision of its family than it stands at (Fresh verdicts)
       (empty) not realized, or no run - the note says which
```

## Fresh verdicts

A verdict stands until a change changes what its family's cases prove, and
the one who makes such a change says so. The conformance package, where the
families are, holds the revision each stands at in
`lib/StateUI/StateUI.Conformance/revisions.txt` - a line naming the family alone on
every host, a line naming a host and the family on that host alone, 1 where
no line names it (`HostVerdict.revision`). A change to the cases, or to what every host
decides alike, raises the family's own; a change one host alone makes raises
that host's. Any other change of the sources - a comment, a sign, a rule no
case proves - raises nothing and leaves every mark standing.

Each host's run writes, over each verdict file it writes, the revision its
family stands at: `# revision 1.1`, every host's, then its own. A host that
reads the repository takes it from the file (`<Host>Exports.revision`);
Android's script writes it over the files it takes off the device
(`.scripts/Marks/revision.sh`). The renderer shows a verdict whose file names
another revision, or none, ⌛ with no note: what it said is no verdict of the
family as it stands, and a note repeating it on every stale cell of every host
only hides the notes that count. A run of the family makes it fresh again;
nothing a person remembers does.

A run asked for the stale families alone - `STATEUI_STALE_ONLY=1`, `-Stale` on
Windows, `StateUI: Conformance - Rebuild changed` in the editor - runs only the
families whose file names another revision, or none, or has no file yet; the
others end at once, their files left as they stand.

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
to a contract's first paragraph, its example, a member or a layer is committed together
with the pages it renders; a host's verdicts are written again through that
host's own suite, with `STATEUI_UPDATE_EXPORTS=1`, and the pages after them.
