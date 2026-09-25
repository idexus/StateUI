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

Each host declares what it realizes in a source of its own: a record per
member, realized in full or in part, the part naming what is missing, and
the elements it does not realize. Its suite also exports what its runtime
registers, and the dictionary joins that export with the contracts, naming
each member under the contract that declares it. What is written comes
first, since a written record may say a realization is partial; the export
adds presence for every member the written half does not speak for, so one
member of one contract is recorded once.

The rule is the host layer's `HostMarks`, a host's records as `HostRecord`s:
the dictionary reads each host's column through it, and a conformance case
asks it whether the host it runs on realizes what the case covers - one rule
for the page and the test.

```text
  ✅   implemented, and covered by that host's tests
  ☑️   implemented and tested, but incomplete; the record names what is missing
       (empty) absent, partial and unverified, or not examined
```

## Rendering again

`STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests` writes the
pages and the matrix's blocks again. Without the variable, the suite refuses
a document that differs from what the contracts render, a record naming a
member no contract declares, a record written twice, and a ☑️ without its
note. A change to a contract's first paragraph, a member, a layer or a
host's record is committed together with the pages it renders. A host's
export is written again through that host's own suite, with
`STATEUI_UPDATE_EXPORTS=1`.
