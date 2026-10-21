# Contracts

Every node type exists through one contract (Core/Contract): an enum naming its
node type and every member it has, each with the type of its value. Swift
writes through the members, so a property and its value meet in the compiler,
and a host realizes the contract member by member.

```text
  enum TrafficLightContract: ElementContract
    nodeType   "Gallery.TrafficLight"
    tiers      [ViewContract.self]            members worn from a tier
    members    signal      ElementProperty<Self, TrafficSignal>
               lampTapped  ElementEvent<Self, Int>

  view:      Node(contract: TrafficLightContract.self)
  modifier:  setValue(TrafficLightContract.signal, value)
  host:      registry.add(TrafficLightContract.self, ...) member by member
```

## Tiers

A tier is a contract with no node type of its own: members many elements share,
declared once - every text control's font size is one member of one tier. An
element names the tiers it wears, and a tier may wear tiers. `Contract.worn`
lists a contract and every tier it wears, each once, in the order met - depth
first, in declaration order - the contract itself first. No contract wears two
members of one name, so each member it wears has one owner
([worn once](../contracts/tiers.md#worn-once-nearest-first)).

What happens with no control behind it - an alert, the clock, a battery
reporting - belongs to the application: `ApplicationTier` is a contract of
acts and events with no control behind them - `ApplicationContract` is one,
and no element lists one among its tiers - and an application declares its
own exactly as the library declares its.

## Members are written with their contract

A member is always written with its contract - `TrafficLightContract.signal`.
A member found as a leading-dot member of its own type cannot be paired with a
single-value payload by the compiler, so nothing is declared for that spelling.
The public API has no road by token.

An element that wears no tier - a map's `Marker`, which stands only among its
map's pins - carries no modifiers but its own. It writes a member on its node,
`node.write(MarkerContract.label, value)`, and hears one,
`node.addHandler(MarkerContract.selected, handler)`: the same typed members a
view's `setValue` and `onEvent` are written over, so the compiler still pairs
each member with its value.

## Member facts

A property says three things about itself beside its value's type and its
layer:

```text
  travels  whether a change animates to the new value (the default). False
           where there is no half way: a place or a count (which tab, which
           row, where the caret is), a law a scroller obeys (read as a release
           is decided), a range or a region (answered by a method or a redraw),
           and a placement the host works out from a measurement
  cleared  whether a value no longer described is put back to the control's
           default (the default). False where no default answers for it, and
           losing it replaces the element: a gesture's settings, a list's
           items, where the host puts an item (a toolbar item's order, a
           swipe's side), a choice clearing would move, and a window's kind,
           value and behavior, which the host keeps its windows by
  moves    which group of a view's values it is for `.motion(_:_:)` - a size,
           a place, a transform, spacing, text - where the value cannot say;
           a color says its own group through its value
```

A host still snaps a transition it cannot interpolate; `travels` keeps the
ones StateUI knows are invalid out of the patch. Every host has to agree with
the members that say `cleared` is false, or the difference shows only on a
screen. A property no library contract declares - an application's own -
animates, is cleared, and says nothing of motion.

## Values that cross

`HostRepresentable` is a member's value and how it crosses and comes back:
`Bool`, `Int` (a `Double`, read back as the whole number nearest it - exact up to 2^53, and
a whole number past it, which arrives rounded, said once; a carried `Int` lane
alike), `Double`, `String`, `UInt8` (a byte), an
optional of any of them (nil crosses as `.nothing`), `PropValue` itself, and an
`Int32` enum (its member's number). A list of `Double` crosses as one run of
numbers, a list of text as one list of text, a list of bytes - a file's
contents - as one run of bytes (`.bytes`); any other list - of `Int` included -
as a list of values.

`MemberValues` encodes a member's positional values - what an event carries,
what an act is handed and what it answers - and decodes them against the
declared types. What crosses is exactly what the declaration says, or it is
refused whole: a handler never runs on a guess, and a refused payload is said
once. The one leniency is at the end: an optional value there may be left out
and reads as nil, which is how a host says it has none - a pointer position the
platform does not know.

## Tokens

`NodeType`, `Prop`, `Event` and `Act` are tokens: structs holding a key - a
name and its number - with the library's entries as static members. A token is
a key and only a key; a host reads it by its name. That is what makes the
library's tokens and an application's the same thing.

Nobody writes a token by hand. A member's token is made from its name - a
token's `init(_ name:)` is the host's alone, behind `@_spi(Host)` - and each
name is spelled once, where a contract declares its member; the library's
tokens (`Tokens.swift`, for the hosts, behind `@_spi(Host)`) are
made from the members, and a guard names any source that spells a name out
instead. A node type is the one token a contract spells, as a literal. Node
types, properties and events are ordered by name, because the differ walks
properties and numbers handlers in name order, and equal where their keys
are ([a key is a number](#a-key-is-a-number)).

An application's own node type can be one no host knows; the host draws an
unknown type as a red marker rather than failing, which keeps a lagging host
visible without hiding the rest of the interface. An application's act shares
the one vocabulary with the library's, and the library's case is consulted
first, so a registration can never shadow it; prefixing an application's names
with its own keeps the two sets apart.

## A key is a number

A key is a name and the number its work is done by (`KeyName`): the name's
64-bit FNV-1a hash, so one name has one number in every process on every
platform, and no run depends on which key it met first. Two keys are equal
where their numbers are, a key hashes its number, and keys order by their
names' bytes - the differ walks properties and numbers handlers in that order;
bytes, as the number is, so two keys are ordered exactly where they are not
equal, which a text comparison treating "é" composed and decomposed alike would
not give. Every element's
values, handlers and type are looked up by key on every render and every
frame; a name would be hashed and compared byte by byte at each, a number is
one word. The number never leaves the process: what crosses to a host or a
file is the name.

A name becomes a key once, where the key is declared: a `static let`, a
contract's member (`token`, `owner`), a host's realization as it is read at
start-up and what the core works out of it when first asked, and a view
type's key, made once a type as the walk first meets it (`typeKey(of:)`).
Making one takes the process's table under a lock (`KeyNumbers`), which stops
a second name of one number, so the library makes no key of a word it meets
during work: a window's kind the platform kept is found among the kinds the
scenes declare, and `Prop`, `Event` and `Act` have no literal form.
`KeyGuardTests` reads every library source for a key made - called or its
initializer named - or a key's name compared or looked up, anywhere else. A name in a file - a kept value, a scene's - stays the file's
word: a key claims its own by its name, and a file never makes a key. A
collection keyed by strings holds the words of a file, an export or a
diagnostic, an identity of the application's data - which comes and goes, and
is no key - or the toolkit's own vocabulary; the guard lists each with which.

## Realizations

A host registers each element contract it realizes with a `Registry`: how the
element's view is made, which members the view takes - one at a time, or the
element whole where a view takes several at once - and which events it
raises, its own or a tier's it wears. The registration is the record of what the host realizes: the core
answers "does this host realize X" from it, and the host makes and updates its
views through it. It is generic over the platform's view type, so every Swift
host takes the same machinery.

```text
  Reports         what a view tells the application: raise(event, values)
                  and report(property, value, as: event) - a user's value lands
                  on the state carrying it and the event is raised with it
  ElementValues   what a registration reads: each member typed, whether it
                  is carried in (the host's to write - the control is the
                  source), and whether the patch changed it
  Registration    property(...), applies(...), raises(...),
                  children(Contract, properties:, events:) - children the view draws
                  itself, a map's markers, handed over whole as ChildElements
  Registry        add, add(madeByHost:), everyElementRealizes/Raises,
                  raises (the application's events), makeView, apply,
                  childTypes, applyChildren, realization
```

A view taking several properties at once names them in `applies`, one by one
or in a `PropertyList` the hosts share, and a list holds properties alone: an
event or an act among them does not compile. Nor does a type of an
application's own offered as properties: `AppliedProperties` keeps its one
requirement on the host's side, and the default it offers every other type is
unavailable. A child the view draws itself is named the same way, its
properties apart from its events (`children(_:properties:events:apply:)`).

A member of a contract the element does not wear is refused and said once, at
registration, at a raise and at a report alike. `apply` puts changed properties registered
alone in name order, then runs each whole applier whose members changed, every
value read as the host presents it - a value in motion or carried by a state
included. An element whose view the host makes itself, because its making needs
machinery no contract describes, registers its members with `madeByHost`. A
view of another class than the registration takes gets nothing applied and is
said once, rather than leaving every member realized in the register and none
on the screen.

A runtime hands over its registry's realization before its first render,
through `CoreLink.setRealization`, with the library's elements it shows none
of - its `unrealized` judgment, the same the control dictionary reads, with
what it leaves to the application and each backend no one registered: every
other element of the library's is realized, and so is every element and member
the registry names, the application's own controls and the events its head
declared among them. Until a host says, the core knows of nothing realized and
says nothing. With it the host hands its register, which the core reads when
first asked rather than as it is handed: building one costs, and a host hands
it at each start.

## What a platform honors

`Device.honors` answers an application asking whether the platform it runs
on honors a member - so a view leaves out what asks for one it does not,
an "Open the list" where no list opens by the program. The answer is the
host's register (`HostRegister`), handed to the core as the runtime starts:
the host's own judgments - in full, in part, never with why - over what its
registry realizes, the same answer the platform contract shows. Before a host
hands one, what its registry said it realizes answers. A tier's member the
register records element by element - realized on a slider, never on a
switch - is honored by its tier in part, so the answer to
`honors(TintElementContract.tint)` is the same before the register comes and
after.

## Declarations

A `HostDeclaration` is what a host declares, read off its own runtime: the
elements it makes a view for and, on each, the members it takes and the events
it raises. It says presence and never ownership: a runtime does not hold the
contracts, and `lineWidth` on a button is the same call whether the button
or a tier it wears declares it. `realization` names each owner against the
contracts themselves, so an owner is never written by hand.

Shared members are said apart because they are realized apart: a host applies
margins, opacity, gestures and focus around every view it makes, so naming them
under one element would be false and under all of them a list nobody maintains.
Each reaches every element wearing the tier that declares it - a tier, never
the element itself: a menu's own `isEnabled` takes nothing from the shared
machinery's, and `realization` and `tierMembers` read a shared name by that
one rule. Acts are said
whole, because a host performs an act against the key it names, and nothing in
the call says which element it belongs to; the contracts do. `tierMembers`
answers shared members from the contracts rather than through the elements, so
a tier worn only by elements the host registers nothing for is still counted.

A member no contract declares is a host and the contracts disagreeing, named by
`undeclared`. An act is not listed there: a host names each act it performs
from its contract's member - a chooser and a prompt from `ApplicationContract` -
so none can be undeclared.

## Unrealized names

A node type described for the first time that the host said it does not realize
is said once, with the realized names nearest to it - at most three, within a
quarter of the name's length in single-character edits (at least two). A
handler listening for an application event the host does not raise is said once
the same way. Nothing is said while the host has said nothing.

In a Debug build, a member described on an element the host realizes is said
once where the host's register says it does not realize it there, or never
will, with the register's reason (`HostRealizations.unhonored`): a tint
written on a control a platform draws in the user's accent compiles and does
nothing, and this is where its author hears why. A member the register says
nothing of, or realizes in part, goes by. The register is built when first
asked, and the host layer keeps it while the host tells the same realization
at each start (`CoreLink.setRealization`).
