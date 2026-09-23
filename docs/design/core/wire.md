# The Wire

The Wire is the patch, the acts and the host's reports as deterministic bytes,
for a runtime that cannot read Swift types (Core/Wire.swift). A Swift host
takes the same model typed (`HostRender`, `HostPatch`) and never sees these
bytes.

## Bytes rather than text

The host and the core share one process and one address space, and every
platform the library targets is little-endian arm64 or x86_64. So numbers cross
as their own bytes, fixed width, with no text in between: an `Int32` here is an
`Int32` there. A message is a byte buffer the host reads in place, with no
UTF-16 round trip and nothing materialized on the way.

A string carries its length, so nothing is ever escaped and a comma inside one
needs no rule. A number crosses as its own bits, so nothing is formatted and a
non-finite number needs no sentinel. The append helpers are the one spelling of
the layout, little-endian and fixed width.

## The channels

```text
  this side writes           the host writes
  the render message         a reply        what an act came to
  an acts batch              a payload      what an event carried
  the persistent keys        a host event   an event raised by name
                             an environment push
                             the persistent values found in the store
                             a realization and a declaration
```

The value channels share one value encoding. The persistent keys, the
realization and the declaration carry names and kinds rather than values.

```text
  reply        [version: U8][ok: U8][count: U8][values...]
               ok 1: the values a `try await` resumes with
               ok 0: exactly one string, the reason it throws
  payload      [version: U8][count: U8][values...]
               an event with nothing to say crosses no bytes at all
  host event   [version: U8][name: string][count: U8][values...]
  environment  [version: U8][domain: U8][count: U8][values...]
               the domain is one byte: the providers are a closed vocabulary
```

## The dictionary

A name - a node type, a property key, an event, an act, a name value - does not
cross as its spelling. Each session numbers the names it uses: the first
message that uses one assigns it the next `UInt16` and announces the pair in its
head, and both sides speak the number from then on (`WireDictionary`).

```text
  an application's names are numbered exactly as the library's are: no
    reserved pool, no table to be missing from, no ledger kept append-only -
    the name is the registration, said once per session
  the host never holds a table from another version: it learns every entry
    from the message itself; a name it does not know degrades gently - an
    unknown property is ignored, an unknown node type draws the marker
  a name costs its spelling once per session, and two bytes after
```

The dictionary is touched only while a message is encoded, which happens on
the host's one thread, so it has no lock of its own. Each test fixture gets a
fresh one, which is what makes a fixture's bytes self-describing.

The counter must not wrap: a number is the host's only handle on a name, and
issuing one twice would quietly rename half a tree. A session that names 65535
different things has a vocabulary growing without end - a font family, a radio
group or a visual state made from a row's own text - and stops with a message
saying so.

## Announcements come first

Announcements sit at the head of a message, before anything that could refer to
them. A batch that fails later in its bytes has still taught the host its names,
so the session's numbering never drifts on a failure. The body is written first,
because writing it discovers which names still need announcing; the head then
carries exactly those.

```text
  announcements   [count: U16] per entry: [id: U16][name: string]
```

## The version

Every message on every value channel starts with `Wire.version`, which changes
only when the layout changes. The host asks `stateui_wire_version` before the
first render and refuses a mismatch loudly: two halves built from different
versions fail at startup with a sentence, never by reading each other's bytes
wrong. The state batch carries raw lanes and no version.

## Values

```text
   1  false
   2  true
   3  number        [F64]
   4  string        [length: U32][UTF-8]
   5  numbers       [count: U16][F64...]
   6  strings       [count: U16][string...]
   7  (unused)
   8  color         [r: U8][g: U8][b: U8][a: U8]
   9  values        [count: U16][value...]
  10  enumeration   [member: I32]
  11  name          [id: U16, from the dictionary]
  12  nothing       (no payload)
```

Tag 4 is text someone wrote, and the only arm that carries a spelling. A closed
vocabulary is tag 10 and rides its member's number (Types/Enums.swift says
whose numbers those are); an open vocabulary an author names - a style key, a
visual state, a font family, a radio group, a window's kind - is tag 11 and
rides the dictionary like a property key; a value made of parts is tag 9 and
rides as its parts, a name nested in a list still riding the dictionary. An
argument or list element that is not there is tag 12, one spelling for absence,
so no corner of the wire reads an empty string, a -1 or an empty list as one.

Tag 7 is unused and nothing is renumbered to close the gap: a number costs
nothing left alone, while moving one has to land on both halves at once.

A colour has a tag of its own because it is the value the tree carries most of
and the cheapest to say exactly: four bytes, no parser and no vocabulary on the
host. The channels are written out one by one rather than packed into a word,
so there is no byte order to agree on.

A host never sends a name: its number belongs to the dictionary this side
writes. Decoding the host's channels handles every other arm.

## The render message

```text
  [version: U8][complete: U8][generation: I32][announcements][root patch]

  patch:  [id][type: U16] then fields, each [marker: U8][payload], then 0
    id      [1][I32] for a key the differ assigned, [2][string] for an .id()

    1  replace      (no payload)   build the control again from this patch
    2  props        [count: U16] per: [property: U16][value]
    3  events       [count: U16] per: [event: U16][handler: I32]
    4  children     [count: U16][patch...]   the sparse form
    5  arranged     [count: U16][patch...]   the complete list, in order
    6  transitions  [count: U16] per: [property: U16][law: I32][millis: U32]
                                      [easing: I32][factor: F64]
    7  cleared      [count: U16][property: U16...]
    8  recycles     [U8]
    9  shape        [U64]
   10  motion       [law: I32], then unless the law is -1:
                    [millis: U32][easing: I32][factor: F64]; always [lanes: U8]
   11  driven       [count: U16] per: [property: U16][number: I32]
                                      [mode: U8][kind: U8]
```

A field is written only when it is present, and a field not there did not
change: optionality costs one byte per present field and nothing per absent
one. The key and the type always come first - the key is how the host finds the
control, and the type is worth its two bytes on every message. An unknown field
throws on arrival, the loud failure a skew deserves.

## Transitions

A transition is not a value and does not ride in one. A property being animated
carries its target as the ordinary value it is; the transitions field beside the
props says which of them the host animates to rather than assigns, and under
which law. A law and nothing else: nobody is told when such an animation ends,
because nobody is waiting - a value that changed is a destination, and a render
in the middle of the animation says the same thing again. A value somebody
awaits is a driven one, animated off its own image.

## Driven states

The driven field says which properties are tied to a carried state: property,
state number, which way it crosses and which door it goes through. One field for
both directions, because a registration is the same fact either way. Eight bytes
an entry and no law: a law is written into the animated value's own lanes,
where a law that changes per write has to live anyway. A property with a number
behind it carries no value on any later message; the host reads it off the
image on its own frames. A property that also has a stated value still carries
it, and the newer of the two destinations is the one in force. The field is
written whenever the set changed, an empty set included.

## Layout motion

The motion field says how an element animates what no property carries: where
it places its children, and what its visual states change. It crosses only from
the elements where the host works something out for itself - one that places
children, one whose visual states change a value, and the application, whose
answer the rest inherit. Law -1 is "the application's", what every layout is
until told otherwise, so the common case is on no message at all; what crosses
is an override and its going away. The lanes byte is always written: a layout
may animate the way the application does and still hold one part of a place
still.

It stands beside the props rather than inside them. A wrapped value would answer
nil from every typed accessor on the host, so a host that did not know the
wrapper would silently not write the property - indistinguishable from "this did
not change" - and a wrapper leaking into the visual-state overlay, which copies
property bags whole, would set a motion nobody asked for.

## Events and children

The events field is written whenever the patch decided the set changed, an
empty set included. An element whose last handler went carries an empty map and
the host replaces its map; skipping it would leave the host keeping an id this
side has forgotten and resolving a gesture to nobody.

The cleared field carries only keys, in name order: there is no value to send
for a property that is gone, and what it goes back to is the host's business.

The arranged form is written even when empty - an element whose last child left
has to say so - and the sparse form only when something is in it.

## The acts batch

```text
  [version: U8][announcements][count: U16]
  per act:  [act: U16, from the dictionary]
            [completion: I32]   0 when nobody waits; real ids are negative
            [argCount: U8][argument values...]
```

## Reading the host channels

Every decoder reads through a bounds-checked cursor: a read past the end
answers nil instead of trapping, so a truncated buffer is a refusal, never a
crash. A payload that would not read is treated as an empty one: the typed
readers find nothing they expect and leave handler and binding alone. A reply
that would not read resumes its handler with a failure, because a reply that
cannot be read must still resume the handler waiting on it. A host event, an
environment push, a realization or the persistent values that would not read
answer -1, which the host reports as version skew rather than nothing.

## Persistent keys

```text
  keys (this side writes)    [version: U8][storage: string][count: U16]
                             per key: [name: string][kind: U8]
  values (the host writes)   [version: U8][count: U16]
                             per entry: [name: string][value]
```

The names cross in full rather than as dictionary numbers: this is the first
thing either side says, before any message has announced anything, and the names
belong to the platform's store rather than to a session. A kind is one byte for
a vocabulary of four. A key the store had nothing under is absent from the
values, which leaves the state holding the value written beside it.

## Realizations and declarations

```text
  realization   [version: U8][elements: U16] per: [name: string]
                [members: U16] per: [element: string][owner: string][member: string]
  declaration   [version: U8][elements: U16] per: [name: string]
                  [members: U16][name...][events: U16][name...]
                [shared members: U16][name...][shared events: U16][name...]
                [acts: U16][name...]
```

Names in full, as the persistent keys are: nothing has announced a dictionary
when a host says what it realizes. Elements are sorted by name and members by
element, owner and member, so one realization is one run of bytes. A
declaration states presence and never ownership - which contract declares a
member is a fact of the contracts, which a host does not hold - and its shared
members ride last and unattached, because a host realizes them around every
view rather than in one registration (contracts.md).

## Limits

Everything in a message is length-prefixed, so a list longer than its prefix
can count cannot be written at all. `Wire.count` names the list and the limit
when that happens, where the plain conversion would end the process on an
arithmetic trap that names neither. A list value nests at most 256 levels on the
way in, so a corrupt count is an unreadable buffer instead of a stack overflow.
A string's length is compared as it crossed - unsigned, 32 bits wide - against
the bytes left, because `Int` is 32 bits on a 32-bit Android target, where a
length past `Int32.max` would trap on the way in rather than be refused.

## Determinism

The same session writes the same bytes on every run. A dictionary has no order
and Swift seeds its hashing per process, so everything written from one is
sorted: properties, transitions, cleared keys, events and driven entries by
name, a node's handler ids assigned in event-name order, state numbers issued in
walk order, and act saves by key. That is what makes two renders of one tree
byte-identical and a fixture a contract.
