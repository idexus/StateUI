# Element contracts

Every node type exists through one element contract: an enum in
`lib/StateUI/Sources/Contracts/Elements` naming the node type, the layer that
realizes it, the tiers it wears, and each member with the type of its value.
A tier, in `Contracts/Tiers` or - one group of members - `Contracts/Mixins`,
is a contract with no node type of its own: members several elements share,
declared once. The contracts stand in the same topic folders as their views:
`Controls`, `Text`, `Layouts`, `Shapes`, `Collections`, `Structure`, `Slots`,
`Navigation`, `Menus`. Views, the differ, the hosts,
the handbook's dictionary and the guards all read the same declarations, so
a property and its value meet in the compiler and nothing is spelled twice.

## The notes

- [Tiers](tiers.md) - the shared members, and which element wears which.
- [Layers](layers.md) - who realizes an element and each of its members.
- [What a member says about itself](member-facts.md) - whether a change
  animates, whether a lost value is cleared, which group of values it is.
- [Structure elements](structure.md) - the parts of an application that are
  not controls, and the slots and collections that hang off them.
- [The application element](application-tier.md) - acts and events with no
  control behind them.
- [The dictionary and the matrix](dictionary.md) - the pages rendered from
  the contracts, and how to write a contract's documentation for them.

## One declaration per node type

```text
  public enum LabelContract: ElementContract
      nodeType   "Label"                  the name a host resolves; the contract's own name
      layer      .native                  who realizes the element
      tiers      View, TextElement, FontElement, TextAlignmentElement,
                 LineHeightElement, DecorableTextElement, PaddingElement
      members    lineBreak      ElementProperty<Self, LineBreak>
                 maximumLines   ElementProperty<Self, Int>     travels: false

  LabelContract.worn    Label, View, VisualElement, PropertyContainer, TextElement,
                        TextStyleElement, FontElement, TextAlignmentElement, ...
                        every tier once, nearest first
```

A member is one of three kinds, each carrying the types it holds:

```text
  ElementProperty<Owner, Value>          a value the element holds       Value: HostRepresentable
  ElementEvent<Owner, Payload>           a report the element raises     nothing, a value, or a tuple
  ElementAct<Owner, Arguments, Answer>   a call a host performs          on an aimed element, or none
```

A member's name is the name of the static member holding it, and it is what
crosses the boundary: `LabelContract.maximumLines` crosses as the property
`maximumLines`. A node type's name is its contract's name without
`Contract`. Every member a contract declares is on its `members` list, and
the list names nothing else: the list is what the dictionary shows and what
a host is held to.

## Who reads a contract

```text
  a contract: node type, layer, tiers, members and their value types
      |
      +--> views           Node(contract: LabelContract.self)
      |                    setValue(LabelContract.maximumLines, 3)       a modifier writes a member
      |                    onEvent(DatePickerContract.dateChanged) {...}  a handler hears it typed
      |                    Aim.call, stateUICall, HostEvents.on           acts and application events
      |
      +--> the differ      Prop.facts, read by name from LibraryContracts:
      |                    whether a change animates, whether a lost value is
      |                    cleared, which group of values it is
      |
      +--> a host          a host registers each element it realizes, member by
      |                    member, and tells the core what it realizes
      |
      +--> the dictionary  docs/controls/*.md and the tables of docs/platform-contract.md,
      |                    rendered from the contracts and each host's declaration
      |
      +--> the guards      every node built through its contract, every member on its
                           list and a token the library declares, one name one set of
                           facts, every removed spelling refused at compile time
```

A tier mirrors a Swift protocol of the same name in `Views`: an element's
view conforms to the protocols whose tiers its contract wears, and a
protocol's modifiers write the tier's members. A tier wears the tiers its
protocol refines, so `View` wears `VisualElement`, which wears
`PropertyContainer`.

## The contracts of the library

`LibraryContracts` lists every contract the library declares: the tiers in
the dictionary's order, then every element. The guards and the tables the
library derives from its contracts read this list, and the differ reads its
facts by name from it; an application declares its own contracts the same
way and registers them with its hosts.
