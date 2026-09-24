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
               flash       ElementAct<Self, Int, Void>

  view:      Node(contract: TrafficLightContract.self)
  modifier:  setValue(TrafficLightContract.signal, value)
  host:      registry.add(TrafficLightContract.self, ...) member by member
```

## Tiers

A tier is a contract with no node type of its own: members many elements share,
declared once - every text control's font size is one member of one tier. An
element names the tiers it wears, and a tier may wear tiers. `Contract.worn`
lists a contract and every tier it wears, each once, nearest first; a member an
element redeclares therefore belongs to the element.

What happens with no control behind it - an alert, the clock, a battery
reporting - belongs to the application: `ApplicationTier` is a tier the
application element wears, and an application declares its own exactly as the
library declares its.

## Members are written with their contract

A member is always written with its contract - `TrafficLightContract.signal`.
A member found as a leading-dot member of its own type cannot be paired with a
single-value payload by the compiler, so nothing is declared for that spelling.
The public API has no road by token.

## Member facts

A property says three things about itself beside its value's type:

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
           value and behaviour, which the host keeps its windows by
  moves    which group of a view's values it is for `.motion(_:_:)` - a size,
           a place, a transform, spacing, text - where the value cannot say;
           a colour says its own group through its value
```

A host still snaps a transition it cannot interpolate; `travels` keeps the
ones StateUI knows are invalid out of the patch. Every host has to agree with
the members that say `cleared` is false, or the difference shows only on a
screen. A property no library contract declares - an application's own -
animates, is cleared, and says nothing of motion.

## Values that cross

`HostRepresentable` is a member's value and how it crosses and comes back:
`Bool`, `Int` (a whole `Double`, refused unless exact), `Double`, `String`, an
optional of any of them (nil crosses as `.nothing`), `PropValue` itself, and an
`Int32` enum (its member's number). A list of numbers crosses as one run of
numbers and a list of text as one list of text; any other list as a list of
values.

`MemberValues` encodes a member's positional values - what an event carries,
what an act is handed and what it answers - and decodes them against the
declared types. What crosses is exactly what the declaration says, or it is
refused whole: a handler never runs on a guess, and a refused payload is said
once. The one leniency is at the end: an optional value there may be left out
and reads as nil, which is how a host says it has none - a pointer position the
platform does not know.

## Tokens

`NodeType`, `Prop`, `Event` and `Act` are tokens: structs holding a name, with
the library's entries as static members. A token is a name and only a name;
a host reads it by that name. That is what makes the library's tokens and an
application's the same thing.

Nobody writes a token by hand. A member's token is made from its name, and each
name is spelled once, where a contract declares its member; the library's
tokens (`Tokens.swift`, for the hosts, behind `@_spi(Host)`) are
made from the members, and a guard names any source that spells a name out
instead. A node type is the one token a contract spells, as a literal. Tokens
compare by name, because a message writes properties and handlers in name
order.

An application's own node type can be one no host knows; the host draws an
unknown type as a red marker rather than failing, which keeps a lagging host
visible without hiding the rest of the interface. An application's act shares
the one vocabulary with the library's, and the library's case is consulted
first, so a registration can never shadow it; prefixing an application's names
with its own keeps the two sets apart.

## Realizations

A host registers each element contract it realizes with a `Registry`: how the
element's view is made, which members the view takes - one at a time, or the
element whole where a view takes several at once - and which of its own events
it raises. The registration is the record of what the host realizes: the core
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
  Registration    property(...), applies([...]), raises(...)
  Registry        add, add(madeByHost:), everyElementRealizes/Raises,
                  raises (the application's events), makeView, apply,
                  realization
```

A member of a contract the element does not wear is refused and said once, at
registration and at report alike. `apply` puts changed properties registered
alone in name order, then runs each whole applier whose members changed, every
value read as the host presents it - a value in motion or carried by a state
included. An element whose view the host makes itself, because its making needs
machinery no contract describes, registers its members with `madeByHost`.

A runtime hands over its registry's realization before its first render,
through `CoreLink.setRealization`, with the library's elements it shows none
of - its `unrealized` judgement, the same the control dictionary reads: every
other element of the library's is realized, and so is every element and member
the registry names, the application's own controls and the events its head
declared among them. Until a host says, the core knows of nothing realized and
says nothing.

## Declarations

A `HostDeclaration` is what a host declares, read off its own runtime: the
elements it makes a view for and, on each, the members it takes and the events
it raises. It says presence and never ownership: a runtime does not hold the
contracts, and `strokeWidth` on a button is the same call whether the button
or a tier it wears declares it. `realization` names each owner against the
contracts themselves, so an owner is never written by hand.

Shared members are said apart because they are realized apart: a host applies
margins, opacity, gestures and focus around every view it makes, so naming them
under one element would be false and under all of them a list nobody maintains.
Each reaches every element wearing the tier that declares it. Acts are said
whole, because a host performs an act against the key it names, and nothing in
the call says which element it belongs to; the contracts do. `tierMembers`
answers shared members from the contracts rather than through the elements, so
a tier worn only by elements the host registers nothing for is still counted.

A member no contract declares is a host and the contracts disagreeing, named by
`undeclared`. An act is held the same way but not listed there: a host performs
some acts of its own - a chooser, a prompt - that no contract declares.

## Unrealized names

A node type described for the first time that the host said it does not realize
is said once, with the realized names nearest to it - at most three, within a
quarter of the name's length in single-character edits (at least two). A
handler listening for an application event the host does not raise is said once
the same way. Nothing is said while the host has said nothing.
