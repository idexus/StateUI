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
  a tier contract
      first paragraph  ------------------------>  the tier's page
      first sentence  ------------------------->  the tier list, and the line over the
                                                  tier's table on every element page
  each host's written declaration + its export  ->  the marks and their notes
  the matrix's native mapping  ---------------->  each page's "Realization:" lines
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
```

A case runs only where the host realizes every member it covers; a member
the register calls never is marked – without the case running. The element
itself has a verdict of its own, `Button: ✅`, from its creation case: the
creation table's mark. A tier's row groups the elements wearing the tier
that the host's run judged - made, or never had.

A host checks its own register in its suite (`HostRegister.problems`): a
record naming what its owner does not declare, one written twice, a partial
one saying nothing is missing, a never saying no reason.

```text
  ✅   proven on that host by its own passing test
  ☑️   proven by its test, but the host records what is missing
  –    never on that host's family; its register says why
       (empty) not proven on that host yet - the note says why, where its run said
```

## Rendering again

`STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests` writes the
pages and the matrix's blocks again. Without the variable, the suite refuses
a document that differs from what the contracts render, a line that is no
verdict, and a verdict on what no contract of its element declares. A change
to a contract's first paragraph, a member or a layer is committed together
with the pages it renders; a host's verdicts are written again through that
host's own suite, with `STATEUI_UPDATE_EXPORTS=1`, and the pages after them.
